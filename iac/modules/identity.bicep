targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Name for the user-assigned managed identity.')
param uamiName string

@description('Customer admin Entra object ID.')
param adminObjectId string

@description('Principal type for adminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param adminPrincipalType string = 'User'

@description('Optional tags to apply.')
param tags object = {}

@description('Optional Log Analytics Workspace name for RBAC wiring.')
param lawName string = ''

// Create the user-assigned managed identity (name provided by parent, includes suffix).
resource vibedataUami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

// Assign Contributor on the Managed Resource Group to the UAMI.
resource uamiContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vibedataUami.id, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: vibedataUami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign Reader on the Managed Resource Group to the customer admin.
resource customerReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, adminObjectId, 'Reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Additional RBAC per RFC-13 / PRD-30
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (!empty(lawName)) {
  name: lawName
}

// Optional: Log Analytics Contributor if lawId provided
resource uamiLawContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(lawName)) {
  name: guid(law.id, vibedataUami.id, 'LAW-Contrib')
  scope: law
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '73c42c96-874c-492b-b04d-ab87d138a893') // Log Analytics Contributor
    principalId: vibedataUami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output uamiPrincipalId string = vibedataUami.properties.principalId
output uamiClientId string = vibedataUami.properties.clientId
output uamiId string = vibedataUami.id
