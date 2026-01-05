targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Logic App name (Consumption).')
param logicName string

@description('User-assigned managed identity resource id.')
param uamiId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('Diagnostic setting name from naming helper.')
param diagLogicName string

@description('Optional tags to apply.')
param tags object = {}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    state: 'Enabled'
  }
}

resource logicDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagLogicName
  scope: logicApp
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'WorkflowRuntime'
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

output logicId string = logicApp.id
