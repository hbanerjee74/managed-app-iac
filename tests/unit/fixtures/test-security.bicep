targetScope = 'resourceGroup'

// Test wrapper for security module
// Depends on: network, identity, diagnostics, dns

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

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
    vault: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
    blob: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
    queue: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net'
    table: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net'
    acr: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
  }
}

// Module under test
module security '../../../iac/modules/security.bicep' = {
  name: 'security'
  params: {
    location: location
    kvName: naming.outputs.names.kv
    storageName: naming.outputs.names.storage
    acrName: naming.outputs.names.acr
    subnetPeId: mockNetworkOutputs.subnetPeId
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peKvName: naming.outputs.names.peKv
    peStBlobName: naming.outputs.names.peStBlob
    peStQueueName: naming.outputs.names.peStQueue
    peStTableName: naming.outputs.names.peStTable
    peAcrName: naming.outputs.names.peAcr
    peKvDnsName: naming.outputs.names.peKvDns
    peStBlobDnsName: naming.outputs.names.peStBlobDns
    peStQueueDnsName: naming.outputs.names.peStQueueDns
    peStTableDnsName: naming.outputs.names.peStTableDns
    peAcrDnsName: naming.outputs.names.peAcrDns
    diagKvName: naming.outputs.names.diagKv
    diagStName: naming.outputs.names.diagSt
    diagAcrName: naming.outputs.names.diagAcr
    tags: {}
  }
}

output names object = naming.outputs.names

