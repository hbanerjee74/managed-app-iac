targetScope = 'resourceGroup'

// Test wrapper for acr module
// Depends on: network, identity, diagnostics, dns

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

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
  uamiPrincipalId: '00000000-0000-0000-0000-000000000000'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

var mockDnsOutputs = {
  zoneIds: {
    acr: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
  }
}

// Module under test
module acr '../../../iac/modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    acrName: naming.outputs.names.acr
    subnetPeId: mockNetworkOutputs.subnetPeId
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peAcrName: naming.outputs.names.peAcr
    peAcrDnsName: naming.outputs.names.peAcrDns
    diagAcrName: naming.outputs.names.diagAcr
    tags: {}
  }
}

output names object = naming.outputs.names

