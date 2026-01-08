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
var mockNetworkOutputs = {
  subnetPeId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-pe'
}

var mockIdentityOutputs = {
  uamiId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-uami'
  uamiPrincipalId: '00000000-0000-0000-0000-000000000000'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

var mockDnsOutputs = {
  zoneIds: {
    automation: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net'
  }
}

// Module under test
module automation '../../../iac/modules/automation.bicep' = {
  name: 'automation'
  params: {
    location: location
    automationName: naming.outputs.names.automation
    uamiId: mockIdentityOutputs.uamiId
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    subnetPeId: mockNetworkOutputs.subnetPeId
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peAutomationName: naming.outputs.names.peAutomation
    peAutomationDnsName: naming.outputs.names.peAutomationDns
    diagAutomationName: naming.outputs.names.diagAutomation
    tags: {}
  }
}

output automationId string = automation.outputs.automationId
output names object = naming.outputs.names

