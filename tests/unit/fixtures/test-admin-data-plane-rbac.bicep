targetScope = 'resourceGroup'

// Test wrapper for admin-data-plane-rbac module
// Depends on: kv, storage, acr, search, cognitive-services

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('Admin Object ID.')
param adminObjectId string

@description('Admin Principal Type.')
param adminPrincipalType string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
  }
}

// Mock resource IDs (these would come from actual deployments in real scenarios)
var mockKvId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/test-kv'
var mockStorageId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/testst'
var mockAcrId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ContainerRegistry/registries/testacr'
var mockSearchId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Search/searchServices/test-search'
var mockAiId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/test-ai'

// Module under test
module adminDataPlaneRbac '../../../iac/modules/admin-data-plane-rbac.bicep' = {
  name: 'admin-data-plane-rbac'
  params: {
    location: location
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    kvId: mockKvId
    storageId: mockStorageId
    acrId: mockAcrId
    searchId: mockSearchId
    aiId: mockAiId
    isManagedApplication: false
    tags: {}
  }
}

output adminKvSecretsUserId string = adminDataPlaneRbac.outputs.adminKvSecretsUserId
output adminStorageBlobReaderId string = adminDataPlaneRbac.outputs.adminStorageBlobReaderId
output adminStorageQueueReaderId string = adminDataPlaneRbac.outputs.adminStorageQueueReaderId
output adminStorageTableReaderId string = adminDataPlaneRbac.outputs.adminStorageTableReaderId
output adminAcrPullId string = adminDataPlaneRbac.outputs.adminAcrPullId
output adminSearchReaderId string = adminDataPlaneRbac.outputs.adminSearchReaderId
output adminCognitiveServicesUserId string = adminDataPlaneRbac.outputs.adminCognitiveServicesUserId
output names object = naming.outputs.names
