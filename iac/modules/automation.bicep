targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Automation Account name.')
param automationName string


@description('Log Analytics Workspace resource ID.')
param lawId string

@description('Diagnostic setting name from naming helper.')
param diagAutomationName string

@description('Optional tags to apply.')
param tags object = {}

resource automation 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    disableLocalAuth: true
  }
}

output automationId string = automation.id

resource automationDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagAutomationName
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

// RBAC assignments moved to consolidated rbac.bicep module
