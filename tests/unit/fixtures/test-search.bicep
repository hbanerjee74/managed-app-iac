targetScope = 'resourceGroup'

// Test wrapper for search module
// Depends on: network, identity, diagnostics, dns

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('AI Services tier (RFC-64: aiServicesTier).')
param aiServicesTier string

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
    search: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net'
  }
}

// Module under test
module search '../../../iac/modules/search.bicep' = {
  name: 'search'
  params: {
    location: location
    aiServicesTier: aiServicesTier
    searchName: naming.outputs.names.search
    subnetPeId: mockNetworkOutputs.subnetPeId
    lawId: mockDiagnosticsOutputs.lawId
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    zoneIds: mockDnsOutputs.zoneIds
    peSearchName: naming.outputs.names.peSearch
    peSearchDnsName: naming.outputs.names.peSearchDns
    diagSearchName: naming.outputs.names.diagSearch
    tags: {}
  }
}

output names object = naming.outputs.names

