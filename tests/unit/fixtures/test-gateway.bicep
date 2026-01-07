targetScope = 'resourceGroup'

// Test wrapper for gateway module
// Depends on: network, diagnostics

@description('Subscription ID for constructing mock resource IDs.')
param subscriptionId string

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('Customer IP ranges for WAF allowlist (RFC-64: customerIpRanges).')
param customerIpRanges array

@description('Publisher IP ranges for WAF allowlist (RFC-64: publisherIpRanges).')
param publisherIpRanges array

@description('Application Gateway capacity (RFC-64: appGwCapacity).')
param appGwCapacity int

@description('Application Gateway SKU (RFC-64: appGwSku).')
param appGwSku string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

// Mock dependency outputs - use actual subscription ID and resource group name
var mockNetworkOutputs = {
  subnetAppgwId: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-appgw'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

// Module under test
module gateway '../../../iac/modules/gateway.bicep' = {
  name: 'gateway'
  params: {
    location: location
    agwName: naming.outputs.names.agw
    pipName: naming.outputs.names.pipAgw
    customerIpRanges: customerIpRanges
    publisherIpRanges: publisherIpRanges
    subnetAppgwId: mockNetworkOutputs.subnetAppgwId
    lawId: mockDiagnosticsOutputs.lawId
    appGwCapacity: appGwCapacity
    appGwSku: appGwSku
    diagAgwName: naming.outputs.names.diagAgw
    tags: {}
  }
}

output names object = naming.outputs.names

