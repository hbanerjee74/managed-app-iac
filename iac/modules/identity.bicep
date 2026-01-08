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

// Propagation delay to allow managed identity to propagate across tenants (required for Managed Apps).
// Uses UAMI identity - even though we're waiting for propagation, the UAMI is available locally
// enough to run a simple sleep script. AzureCLI is simpler than PowerShell for this use case.
resource propagationDelay 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'propagation-delay'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${vibedataUami.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.61.0'
    scriptContent: 'sleep 30'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    vibedataUami
  ]
}

// Assign Contributor on the Managed Resource Group to the UAMI.
resource uamiContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vibedataUami.id, 'Contributor')
  scope: resourceGroup()  // Explicitly scope to MRG
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: vibedataUami.properties.principalId
    principalType: 'ServicePrincipal'
    delegatedManagedIdentityResourceId: vibedataUami.id  // Required for Managed Apps (cross-tenant scenarios)
  }
  dependsOn: [
    vibedataUami
    propagationDelay  // Wait for propagation
  ]
}

// Assign Reader on the Managed Resource Group to the customer admin.
resource customerReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, adminObjectId, 'Reader')
  scope: resourceGroup()  // Explicitly scope to MRG
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
    delegatedManagedIdentityResourceId: vibedataUami.id  // Required for Managed Apps
  }
  dependsOn: [
    vibedataUami
    propagationDelay
  ]
}

output uamiPrincipalId string = vibedataUami.properties.principalId
output uamiClientId string = vibedataUami.properties.clientId
output uamiId string = vibedataUami.id
