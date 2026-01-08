targetScope = 'resourceGroup'

// Test wrapper for bastion module
// Depends on: network

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
  subnetBastionId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-bastion'
}

// Module under test
module bastion '../../../iac/modules/bastion.bicep' = {
  name: 'bastion'
  params: {
    location: location
    bastionName: naming.outputs.names.bastion
    pipBastionName: naming.outputs.names.pipBastion
    subnetBastionId: mockNetworkOutputs.subnetBastionId
    tags: {}
  }
}

output bastionId string = bastion.outputs.bastionId
output bastionName string = bastion.outputs.bastionName
output names object = naming.outputs.names
