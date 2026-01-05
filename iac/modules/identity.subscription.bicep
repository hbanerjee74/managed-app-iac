targetScope = 'subscription'

@description('Principal ID of the UAMI for subscription-scope RBAC.')
param uamiPrincipalId string

// Cost Management Reader on subscription
resource uamiCostReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, uamiPrincipalId, 'CostReader')
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '72fafb9e-0641-4937-9268-5baf55e7ff7f') // Cost Management Reader
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}
