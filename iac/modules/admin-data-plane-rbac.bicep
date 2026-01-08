targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Customer admin Entra object ID.')
param adminObjectId string

@description('Principal type for adminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param adminPrincipalType string = 'User'

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

@description('Whether this is a managed application deployment (cross-tenant). Set to false for same-tenant testing.')
param isManagedApplication bool = true

@description('Optional tags to apply.')
param tags object = {}

// Key Vault: Key Vault Secrets User (read-only access to secrets)
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: split(kvId, '/')[8]
}

resource adminKvSecretsUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, adminObjectId, 'kv-secrets-user')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Storage Account: Storage Blob Data Reader
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: split(storageId, '/')[8]
}

resource adminStorageBlobReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, adminObjectId, 'st-blob-reader')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Storage Account: Storage Queue Data Reader
resource adminStorageQueueReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, adminObjectId, 'st-queue-reader')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '19e7f393-937e-4f77-808e-945a386e9b0a') // Storage Queue Data Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Storage Account: Storage Table Data Reader
resource adminStorageTableReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, adminObjectId, 'st-table-reader')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '76199698-9eea-4c19-bc75-cec21354c015') // Storage Table Data Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Container Registry: AcrPull (read-only access to images)
resource acr 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = {
  name: split(acrId, '/')[8]
}

resource adminAcrPull 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, adminObjectId, 'acr-pull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Azure AI Search: Search Service Reader
resource search 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: split(searchId, '/')[8]
}

resource adminSearchReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(search.id, adminObjectId, 'search-reader')
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '88308d66-4209-4f3e-9b77-8200b49e9c22') // Search Service Reader
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

// Cognitive Services: Cognitive Services User (read-only access)
resource ai 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: split(aiId, '/')[8]
}

resource adminCognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(ai.id, adminObjectId, 'ai-user')
  scope: ai
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: adminObjectId
    principalType: adminPrincipalType
  }
}

output adminKvSecretsUserId string = adminKvSecretsUser.id
output adminStorageBlobReaderId string = adminStorageBlobReader.id
output adminStorageQueueReaderId string = adminStorageQueueReader.id
output adminStorageTableReaderId string = adminStorageTableReader.id
output adminAcrPullId string = adminAcrPull.id
output adminSearchReaderId string = adminSearchReader.id
output adminCognitiveServicesUserId string = adminCognitiveServicesUser.id
