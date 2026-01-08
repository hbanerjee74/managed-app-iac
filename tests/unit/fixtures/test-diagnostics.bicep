targetScope = 'resourceGroup'

// Test wrapper for diagnostics module
// This module has no dependencies, so it's a good starting point for testing

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('Log Analytics retention in days (RFC-64: retentionDays).')
param retentionDays int

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

// Module under test
module diagnostics '../../../iac/modules/diagnostics.bicep' = {
  name: 'diagnostics'
  params: {
    location: location
    retentionDays: retentionDays
    lawName: naming.outputs.names.law
    tags: {}
  }
}

output lawId string = diagnostics.outputs.lawId
output lawWorkspaceId string = diagnostics.outputs.lawWorkspaceId
output names object = naming.outputs.names

