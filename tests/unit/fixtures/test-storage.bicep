targetScope = 'resourceGroup'

// Test wrapper for storage module
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
    blob: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
    queue: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net'
    table: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net'
  }
}

// Module under test
module storage '../../../iac/modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageName: naming.outputs.names.storage
    subnetPeId: mockNetworkOutputs.subnetPeId
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peStBlobName: naming.outputs.names.peStBlob
    peStQueueName: naming.outputs.names.peStQueue
    peStTableName: naming.outputs.names.peStTable
    peStBlobDnsName: naming.outputs.names.peStBlobDns
    peStQueueDnsName: naming.outputs.names.peStQueueDns
    peStTableDnsName: naming.outputs.names.peStTableDns
    diagStName: naming.outputs.names.diagSt
    tags: {}
  }
}

output names object = naming.outputs.names

