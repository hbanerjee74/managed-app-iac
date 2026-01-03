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

output uamiPrincipalId string = vibedataUami.properties.principalId
output uamiClientId string = vibedataUami.properties.clientId
output uamiId string = vibedataUami.id
