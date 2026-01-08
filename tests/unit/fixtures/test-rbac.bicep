targetScope = 'resourceGroup'

// Test wrapper for rbac module
// Depends on: identity, diagnostics, kv, storage, acr, search, cognitive-services, automation

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('Customer Admin Object ID.')
param customerAdminObjectId string

@description('Customer Admin Principal Type.')
param customerAdminPrincipalType string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
  }
}

// Mock dependency outputs
var mockIdentityOutputs = {
  uamiPrincipalId: '00000000-0000-0000-0000-000000000000'
  uamiId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-uami'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

// Mock resource IDs
var mockKvId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/test-kv'
var mockStorageId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/testst'
var mockAcrId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ContainerRegistry/registries/testacr'
var mockSearchId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Search/searchServices/test-search'
var mockAiId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/test-ai'
var mockAutomationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Automation/automationAccounts/test-automation'

// Module under test
module rbac '../../../iac/modules/rbac.bicep' = {
  name: 'rbac'
  params: {
    location: location
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    uamiId: mockIdentityOutputs.uamiId
    customerAdminObjectId: customerAdminObjectId
    customerAdminPrincipalType: customerAdminPrincipalType
    lawId: mockDiagnosticsOutputs.lawId
    lawName: naming.outputs.names.law
    kvId: mockKvId
    storageId: mockStorageId
    acrId: mockAcrId
    searchId: mockSearchId
    aiId: mockAiId
    automationId: mockAutomationId
    isManagedApplication: false
    tags: {}
  }
}

output names object = naming.outputs.names
