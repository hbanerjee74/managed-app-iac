targetScope = 'resourceGroup'

// Test wrapper for logic module
// Depends on: identity, diagnostics

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

// Mock dependency outputs
var mockIdentityOutputs = {
  uamiId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-uami'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

// Module under test
module logic '../../../iac/modules/logic.bicep' = {
  name: 'logic'
  params: {
    location: location
    logicName: naming.outputs.names.logic
    uamiId: mockIdentityOutputs.uamiId
    lawId: mockDiagnosticsOutputs.lawId
    diagLogicName: naming.outputs.names.diagLogic
    tags: {}
  }
}

output logicId string = logic.outputs.logicId
output names object = naming.outputs.names

