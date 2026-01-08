targetScope = 'resourceGroup'

// Test wrapper for dns module
// Depends on: network

@description('Resource group name for naming seed.')
param resourceGroupName string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

// Mock network output (VNet name)
var mockNetworkOutputs = {
  vnetName: naming.outputs.names.vnet
}

// Module under test
module dns '../../../iac/modules/dns.bicep' = {
  name: 'dns'
  params: {
    vnetName: mockNetworkOutputs.vnetName
    tags: {}
  }
}

output zoneIds object = dns.outputs.zoneIds
output vnetLinkIds object = dns.outputs.vnetLinkIds
output names object = naming.outputs.names

