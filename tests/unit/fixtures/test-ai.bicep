targetScope = 'resourceGroup'

// Test wrapper for ai module
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
  scope: subscription()
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
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
    ai: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  }
}

// Module under test
module ai '../../../iac/modules/ai.bicep' = {
  name: 'ai'
  params: {
    location: location
    aiServicesTier: aiServicesTier
    searchName: naming.outputs.names.search
    aiName: naming.outputs.names.ai
    subnetPeId: mockNetworkOutputs.subnetPeId
    lawId: mockDiagnosticsOutputs.lawId
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    zoneIds: mockDnsOutputs.zoneIds
    peSearchName: naming.outputs.names.peSearch
    peAiName: naming.outputs.names.peAi
    peSearchDnsName: naming.outputs.names.peSearchDns
    peAiDnsName: naming.outputs.names.peAiDns
    diagSearchName: naming.outputs.names.diagSearch
    diagAiName: naming.outputs.names.diagAi
    tags: {}
  }
}

output names object = naming.outputs.names

