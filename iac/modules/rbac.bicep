targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('User-assigned managed identity principal ID.')
param uamiPrincipalId string

@description('User-assigned managed identity resource ID.')
param uamiId string

@description('Customer admin Entra object ID.')
param adminObjectId string

@description('Principal type for adminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param adminPrincipalType string = 'User'

@description('Log Analytics Workspace resource ID.')
param lawId string = ''

@description('Log Analytics Workspace name.')
param lawName string = ''

@description('Key Vault resource ID.')
param kvId string

@description('Storage Account resource ID.')
param storageId string

@description('Container Registry resource ID.')
param acrId string

@description('Azure AI Search resource ID.')
param searchId string

@description('Cognitive Services resource ID.')
param aiId string

@description('Automation Account resource ID.')
param automationId string

@description('Whether this is a managed application deployment (cross-tenant). Set to false for same-tenant testing.')
param isManagedApplication bool = true

@description('Optional tags to apply.')
param tags object = {}

// ============================================================================
// UAMI RBAC ASSIGNMENTS
// ============================================================================

// UAMI: Contributor on Resource Group
resource uamiContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, uamiId, 'Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
    delegatedManagedIdentityResourceId: isManagedApplication ? uamiId : null
  }
}

// UAMI: Log Analytics Contributor (if LAW provided)
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (!empty(lawName)) {
  name: lawName
}

resource uamiLawContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(lawName)) {
  name: guid(law.id, uamiId, 'LAW-Contrib')
  scope: law
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '73c42c96-874c-492b-b04d-ab87d138a893') // Log Analytics Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
    delegatedManagedIdentityResourceId: isManagedApplication ? uamiId : null
  }
  dependsOn: [
    law
  ]
}

// UAMI: Key Vault Secrets Officer
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: split(kvId, '/')[8]
}

resource uamiKvSecretsOfficer 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, uamiPrincipalId, 'kv-secret-officer')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    kv
  ]
}

// UAMI: Storage Blob Data Contributor
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: split(storageId, '/')[8]
}

resource uamiStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, uamiPrincipalId, 'st-blob-data-contrib')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storage
  ]
}

// UAMI: Storage Queue Data Contributor
resource uamiStorageQueueContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, uamiPrincipalId, 'st-queue-data-contrib')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storage
  ]
}

// UAMI: Storage Table Data Contributor
resource uamiStorageTableContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, uamiPrincipalId, 'st-table-data-contrib')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storage
  ]
}

// UAMI: AcrPull
resource acr 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = {
  name: split(acrId, '/')[8]
}

resource uamiAcrPull 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, uamiPrincipalId, 'acr-pull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    acr
  ]
}

// UAMI: AcrPush
resource uamiAcrPush 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, uamiPrincipalId, 'acr-push')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec') // AcrPush
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    acr
  ]
}

// UAMI: Search Service Contributor
resource search 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: split(searchId, '/')[8]
}

resource uamiSearchContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(search.id, uamiPrincipalId, 'search-contrib')
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772') // Search Service Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    search
  ]
}

// UAMI: Cognitive Services Contributor
resource ai 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: split(aiId, '/')[8]
}

resource uamiAiContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(ai.id, uamiPrincipalId, 'ai-contrib')
  scope: ai
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    ai
  ]
}

// UAMI: Automation Job Operator
resource automation 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: split(automationId, '/')[8]
}

resource uamiAutomationJobOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(automation.id, uamiPrincipalId, 'automation-job-operator')
  scope: automation
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4fe576fe-1146-4730-92eb-48519fa6bf9f') // Automation Job Operator
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    automation
  ]
}

// ============================================================================
// ADMIN RBAC ASSIGNMENTS
// ============================================================================

// Admin: Reader on Resource Group
resource adminReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, adminObjectId, 'Reader')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Admin: Key Vault Secrets User (read-only access to secrets)
resource adminKvSecretsUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, adminObjectId, 'kv-secrets-user')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    kv
  ]
}

// Admin: Storage Blob Data Reader
resource adminStorageBlobReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, adminObjectId, 'st-blob-reader')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    storage
  ]
}

// Admin: Storage Queue Data Reader
resource adminStorageQueueReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, adminObjectId, 'st-queue-reader')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '19e7f393-937e-4f77-808e-945a386e9b0a') // Storage Queue Data Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    storage
  ]
}

// Admin: Storage Table Data Reader
resource adminStorageTableReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, adminObjectId, 'st-table-reader')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '76199698-9eea-4c19-bc75-cec21354c015') // Storage Table Data Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    storage
  ]
}

// Admin: AcrPull (read-only access to images)
resource adminAcrPull 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, adminObjectId, 'acr-pull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    acr
  ]
}

// Admin: Search Service Reader
resource adminSearchReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(search.id, adminObjectId, 'search-reader')
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '88308d66-4209-4f3e-9b77-8200b49e9c22') // Search Service Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    search
  ]
}

// Admin: Cognitive Services User (read-only access)
resource adminCognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(ai.id, adminObjectId, 'ai-user')
  scope: ai
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    ai
  ]
}

// Admin: Automation Job Operator
resource adminAutomationJobOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(adminObjectId)) {
  name: guid(automation.id, adminObjectId, 'automation-job-operator')
  scope: automation
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4fe576fe-1146-4730-92eb-48519fa6bf9f') // Automation Job Operator
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
  dependsOn: [
    automation
  ]
}
