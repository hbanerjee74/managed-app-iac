targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('VNet resource ID.')
param vnetId string

@description('Storage Account resource ID for VNet flow logs.')
param storageAccountId string

@description('VNet flow log name from naming helper.')
param vnetFlowLogName string

@description('User-assigned managed identity ID for deployment script.')
param uamiId string

@description('Optional tags to apply.')
param tags object = {}

// VNet Flow Logs (replacing deprecated NSG flow logs per Microsoft deprecation timeline)
// Network Watcher is subscription-scoped and auto-created per region
// Reference: https://learn.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-overview
// Note: Network Watcher is automatically created by Azure per region with name "NetworkWatcher_<region>"
// Bicep limitation: Cannot create subscription-scoped Network Watcher from resource group template
// Solution: Use Azure CLI deployment script to create flow logs
var networkWatcherName = 'NetworkWatcher_${location}'
var networkWatcherId = subscriptionResourceId('Microsoft.Network/networkWatchers', networkWatcherName)
var flowLogId = '${networkWatcherId}/flowLogs/${vnetFlowLogName}'

// Convert tags object to JSON string for Azure CLI
var tagsJson = string(tags)

// Create VNet flow logs using Azure CLI deployment script
// Network Watcher is auto-created by Azure, we just create flow logs
resource createFlowLogs 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'create-vnet-flow-logs-${uniqueString(resourceGroup().id, vnetFlowLogName)}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    azCliVersion: '2.57.0'
    scriptContent: '''
      set -e
      
      NETWORK_WATCHER_NAME="${networkWatcherName}"
      LOCATION="${location}"
      RESOURCE_GROUP="${resourceGroupName}"
      FLOW_LOG_NAME="${vnetFlowLogName}"
      VNET_ID="${vnetId}"
      STORAGE_ACCOUNT_ID="${storageAccountId}"
      
      # Ensure Network Watcher exists (auto-created by Azure, but we verify)
      if ! az network watcher show --name "$NETWORK_WATCHER_NAME" --location "$LOCATION" &>/dev/null; then
        echo "Network Watcher not found, configuring..."
        az network watcher configure --resource-group "$RESOURCE_GROUP" --locations "$LOCATION" --enabled true
      fi
      
      # Extract storage account name from storage account ID
      STORAGE_ACCOUNT_NAME=$(echo "$STORAGE_ACCOUNT_ID" | sed 's|.*/||')
      
      # Create VNet flow log (idempotent - will update if exists)
      if az network watcher flow-log show --resource-group "$RESOURCE_GROUP" --name "$FLOW_LOG_NAME" --location "$LOCATION" &>/dev/null; then
        echo "Flow log exists, updating..."
        az network watcher flow-log update \\
          --resource-group "$RESOURCE_GROUP" \\
          --name "$FLOW_LOG_NAME" \\
          --location "$LOCATION" \\
          --enabled true \\
          --retention 0
      else
        echo "Creating new flow log..."
        az network watcher flow-log create \\
          --resource-group "$RESOURCE_GROUP" \\
          --name "$FLOW_LOG_NAME" \\
          --location "$LOCATION" \\
          --target-resource-id "$VNET_ID" \\
          --storage-account "$STORAGE_ACCOUNT_NAME" \\
          --enabled true \\
          --format json \\
          --version 2 \\
          --retention 0
      fi
      
      echo "VNet flow log created/updated successfully"
    '''
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

// Output the flow log resource ID (constructed, not from script)
output vnetFlowLogId string = flowLogId

