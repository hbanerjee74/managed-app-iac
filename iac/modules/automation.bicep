targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Automation Account name.')
param automationName string

@description('User-assigned managed identity resource id.')
param uamiId string

@description('Admin Object ID for customer (for Automation role).')
param adminObjectId string

@description('Principal type for adminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param adminPrincipalType string = 'User'

@description('Private Endpoints subnet ID.')
param subnetPeId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('Optional tags to apply.')
param tags object = {}

resource automation 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    publicNetworkAccess: false
    disableLocalAuth: true
  }
}

output automationId string = automation.id

resource peAutomation 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${automation.name}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'automation-conn'
        properties: {
          groupIds: [
            'AzureAutomation'
          ]
          privateLinkServiceId: automation.id
        }
      }
    ]
  }
}

resource peAutomationDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peAutomation
  name: 'automation-dns'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.azure-automation.net'
        properties: {
          privateDnsZoneId: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.azure-automation.net')
        }
      }
    ]
  }
}

resource automationDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-law-automation'
  scope: automation
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'JobLogs'
        enabled: true
      }
      {
        category: 'JobStreams'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Automation Job Operator for adminObjectId
resource adminAutomationJobOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(automation.id, adminObjectId, 'automation-job-operator')
  scope: automation
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4fe576fe-1146-4730-92eb-48519fa6bf9f')
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// TODO: deploy Automation Account with UAMI and disable local auth.
