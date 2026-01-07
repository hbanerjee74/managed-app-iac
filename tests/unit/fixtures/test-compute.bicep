targetScope = 'resourceGroup'

// Test wrapper for compute module
// Depends on: network, identity, diagnostics, dns

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('App Service Plan SKU (RFC-64: sku).')
param sku string

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
  subnetAppsvcId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-appsvc'
  subnetPeId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-pe'
}

var mockIdentityOutputs = {
  uamiId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-uami'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

var mockDnsOutputs = {
  zoneIds: {
    appsvc: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net'
  }
}

// Module under test
module compute '../../../iac/modules/compute.bicep' = {
  name: 'compute'
  params: {
    location: location
    sku: sku
    aspName: naming.outputs.names.asp
    appApiName: naming.outputs.names.appApi
    appUiName: naming.outputs.names.appUi
    funcName: naming.outputs.names.funcOps
    subnetAppsvcId: mockNetworkOutputs.subnetAppsvcId
    subnetPeId: mockNetworkOutputs.subnetPeId
    uamiId: mockIdentityOutputs.uamiId
    storageAccountName: naming.outputs.names.storage
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peAppApiName: naming.outputs.names.peAppApi
    peAppUiName: naming.outputs.names.peAppUi
    peFuncName: naming.outputs.names.peFunc
    peAppApiDnsName: naming.outputs.names.peAppApiDns
    peAppUiDnsName: naming.outputs.names.peAppUiDns
    peFuncDnsName: naming.outputs.names.peFuncDns
    diagAppApiName: naming.outputs.names.diagAppApi
    diagAppUiName: naming.outputs.names.diagAppUi
    diagFuncName: naming.outputs.names.diagFunc
    tags: {}
  }
}

output names object = naming.outputs.names

