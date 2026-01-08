targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('App Service Plan SKU (RFC-64 sku).')
param sku string

@description('App Service Plan name.')
param aspName string

@description('Optional tags to apply.')
param tags object = {}

// Determine tier based on SKU
var tier = startsWith(sku, 'B') ? 'Basic' : startsWith(sku, 'S') ? 'Standard' : 'PremiumV3'

resource asp 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: aspName
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: sku
    tier: tier
  }
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

// App Service Plan only - App Services will be deployed separately when needed.
