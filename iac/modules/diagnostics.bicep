targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Log Analytics retention in days.')
param retentionDays int

@description('Log Analytics Workspace name.')
param lawName string

@description('Tags to apply.')
param tags object

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Custom table required by PRD-30
resource customTable 'Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview' = {
  parent: law
  name: 'VibeData_Operations_CL'
  properties: {
    retentionInDays: retentionDays
    totalRetentionInDays: retentionDays
    schema: {
      name: 'VibeData_Operations_CL'
      columns: [
        { name: 'TimeGenerated', type: 'datetime' }
        { name: 'Category', type: 'string' }
        { name: 'CorrelationId', type: 'string' }
        { name: 'InstanceId', type: 'string' }
        { name: 'ComponentId', type: 'string' }
        { name: 'Operation', type: 'string' }
        { name: 'Status', type: 'string' }
        { name: 'DurationMs', type: 'long' }
        { name: 'Message', type: 'string' }
        { name: 'Details', type: 'dynamic' }
      ]
    }
  }
}

output lawId string = law.id
output lawWorkspaceId string = law.properties.customerId
