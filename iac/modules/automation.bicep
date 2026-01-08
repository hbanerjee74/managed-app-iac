targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Automation Account name.')
param automationName string

@description('User-assigned managed identity resource id (deprecated - using SystemAssigned).')
param uamiId string = ''

@description('Principal ID of the UAMI for RBAC (optional).')
param uamiPrincipalId string = ''

@description('Admin Object ID for customer (for Automation role).')
param adminObjectId string

@description('Principal type for adminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param adminPrincipalType string = 'User'

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
    publicNetworkAccess: false
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

// Automation Job Operator for UAMI
resource uamiAutomationJobOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(uamiPrincipalId)) {
  name: guid(automation.id, uamiPrincipalId, 'automation-job-operator')
  scope: automation
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4fe576fe-1146-4730-92eb-48519fa6bf9f') // Automation Job Operator
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Automation Job Operator for adminObjectId (only if provided and not placeholder)
resource adminAutomationJobOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(adminObjectId) && adminObjectId != '00000000-0000-0000-0000-000000000000') {
  name: guid(automation.id, adminObjectId, 'automation-job-operator')
  scope: automation
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4fe576fe-1146-4730-92eb-48519fa6bf9f') // Automation Job Operator
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}
