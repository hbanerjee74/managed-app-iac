targetScope = 'resourceGroup'

// Test wrapper for network module
// This module has no dependencies

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('VNet address prefix (CIDR notation, e.g., 10.20.0.0/16).')
param vnetCidr string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
  }
}

// Module under test
module network '../../../iac/modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: naming.outputs.names.vnet
    vnetCidr: vnetCidr
    nsgAppgwName: naming.outputs.names.nsgAppgw
    nsgAksName: naming.outputs.names.nsgAks
    nsgAppsvcName: naming.outputs.names.nsgAppsvc
    nsgPeName: naming.outputs.names.nsgPe
    tags: {}
  }
}

output subnetPsqlId string = network.outputs.subnetPsqlId
output subnetAppsvcId string = network.outputs.subnetAppsvcId
output subnetPeId string = network.outputs.subnetPeId
output subnetAppgwId string = network.outputs.subnetAppgwId
output names object = naming.outputs.names

