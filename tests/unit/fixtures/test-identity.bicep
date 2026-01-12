targetScope = 'resourceGroup'

// Test wrapper for identity module
// Depends on: diagnostics

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
    tags: {}
  }
}

output uamiPrincipalId string = identity.outputs.uamiPrincipalId
output uamiClientId string = identity.outputs.uamiClientId
output uamiId string = identity.outputs.uamiId
output names object = naming.outputs.names

