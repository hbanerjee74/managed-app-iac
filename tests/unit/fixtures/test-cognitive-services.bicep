targetScope = 'resourceGroup'

// Test wrapper for cognitive-services module
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
    ai: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  }
}

// Module under test
module cognitiveServices '../../../iac/modules/cognitive-services.bicep' = {
  name: 'cognitive-services'
  params: {
    location: location
    aiName: naming.outputs.names.ai
    subnetPeId: mockNetworkOutputs.subnetPeId
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peAiName: naming.outputs.names.peAi
    peAiDnsName: naming.outputs.names.peAiDns
    diagAiName: naming.outputs.names.diagAi
    tags: {}
  }
}

output names object = naming.outputs.names

