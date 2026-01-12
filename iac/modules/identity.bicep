targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Name for the user-assigned managed identity.')
param uamiName string

@description('Tags to apply.')
param tags object

// Create the user-assigned managed identity (name provided by parent, includes suffix).
resource vibedataUami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

// RBAC assignments moved to consolidated rbac.bicep module

output uamiPrincipalId string = vibedataUami.properties.principalId
output uamiClientId string = vibedataUami.properties.clientId
output uamiId string = vibedataUami.id
