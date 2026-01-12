targetScope = 'resourceGroup'

// Test wrapper for kv module
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

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

var mockDnsOutputs = {
  zoneIds: {
    vault: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
  }
}

// Module under test
module kv '../../../iac/modules/kv.bicep' = {
  name: 'kv'
  params: {
    location: location
    kvName: naming.outputs.names.kv
    subnetPeId: mockNetworkOutputs.subnetPeId
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peKvName: naming.outputs.names.peKv
    peKvDnsName: naming.outputs.names.peKvDns
    diagKvName: naming.outputs.names.diagKv
    tags: {}
  }
}

output names object = naming.outputs.names

