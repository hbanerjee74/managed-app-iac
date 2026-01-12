targetScope = 'resourceGroup'

// Test wrapper for app module

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('App Service Plan SKU (RFC-64: sku).')
param sku string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
  }
}

// Module under test
module app '../../../iac/modules/app.bicep' = {
  name: 'app'
  params: {
    location: location
    sku: sku
    aspName: naming.outputs.names.asp
    tags: {}
  }
}

output names object = naming.outputs.names

