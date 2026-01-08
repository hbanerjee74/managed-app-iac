targetScope = 'resourceGroup'

// Test wrapper for automation module
// Depends on: network, identity, diagnostics, dns

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

// Mock dependency outputs
var mockIdentityOutputs = {
  uamiPrincipalId: '00000000-0000-0000-0000-000000000000'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

// Module under test
module automation '../../../iac/modules/automation.bicep' = {
  name: 'automation'
  params: {
    location: location
    automationName: naming.outputs.names.automation
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    lawId: mockDiagnosticsOutputs.lawId
    diagAutomationName: naming.outputs.names.diagAutomation
    tags: {}
  }
}

output automationId string = automation.outputs.automationId
output names object = naming.outputs.names

