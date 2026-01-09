targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Automation Account name.')
param automationName string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('Diagnostic setting name from naming helper.')
param diagAutomationName string

@description('Tags to apply.')
param tags object

@description('Deployer object ID for Automation Job Operator role assignment.')
param deployerObjectId string = ''

@description('Deployer principal type (User or ServicePrincipal).')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

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

// Grant Automation Job Operator role to deployer identity
// This allows the identity running the deployment script to execute automation runbooks
resource deployerAutomationJobOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(deployerObjectId)) {
  name: guid(resourceGroup().id, 'automation', deployerObjectId, 'automation-job-operator')
  scope: automation
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4fe576fe-1146-4730-92eb-48519fa6bf9f') // Automation Job Operator
    principalId: deployerObjectId
    principalType: deployerPrincipalType
    // Role assignments are created directly without delegated managed identity for single-tenant deployments
  }
  dependsOn: [
    automation
  ]
}

output automationId string = automation.id
output automationName string = automation.name

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
  dependsOn: [
    automation
  ]
}

// RBAC assignments moved to consolidated rbac.bicep module
// Runbook creation moved to psql-roles.bicep module
