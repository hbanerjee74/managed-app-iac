targetScope = 'resourceGroup'

// Test wrapper for identity module
// Depends on: diagnostics

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
  scope: subscription()
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

// Mock diagnostics output
var mockDiagnosticsOutputs = {
  lawName: naming.outputs.names.law
}

// Module under test
module identity '../../../iac/modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
    uamiName: naming.outputs.names.uami
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    lawName: mockDiagnosticsOutputs.lawName
    tags: {}
  }
}

output uamiPrincipalId string = identity.outputs.uamiPrincipalId
output uamiClientId string = identity.outputs.uamiClientId
output uamiId string = identity.outputs.uamiId
output names object = naming.outputs.names

