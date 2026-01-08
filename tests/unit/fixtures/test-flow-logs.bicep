targetScope = 'resourceGroup'

// Test wrapper for flow-logs module
// This module requires network and storage to be deployed first

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

// Mock VNet ID (would come from network module in real deployment)
var mockVnetId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Network/virtualNetworks/vd-vnet-platform-test'

// Mock Storage Account ID (would come from storage module in real deployment)
var mockStorageAccountId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Storage/storageAccounts/vdstplatformtest'

// Mock UAMI ID (would come from identity module in real deployment)
var mockUamiId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/vd-uami-platform-test'

// Module under test
module flowLogs '../../../iac/modules/flow-logs.bicep' = {
  name: 'flow-logs'
  params: {
    location: location
    vnetId: mockVnetId
    storageAccountId: mockStorageAccountId
    vnetFlowLogName: naming.outputs.names.vnetFlowLog
    uamiId: mockUamiId
    tags: {}
  }
}

output vnetFlowLogId string = flowLogs.outputs.vnetFlowLogId
output names object = naming.outputs.names

