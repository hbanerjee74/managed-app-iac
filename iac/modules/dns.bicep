targetScope = 'resourceGroup'

@description('Name of the Services VNet to link.')
param vnetName string

@description('Optional tags to apply.')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

var storageSuffix = environment().suffixes.storage
var zones = [
  'privatelink.vaultcore.azure.net'
  'privatelink.postgres.database.azure.com'
  'privatelink.blob.${storageSuffix}'
  'privatelink.queue.${storageSuffix}'
  'privatelink.table.${storageSuffix}'
  'privatelink.azurecr.io'
  'privatelink.azurewebsites.net'
  'privatelink.search.windows.net'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.azure-automation.net'
  'vibedata.internal'
]

resource privateZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in zones: {
  name: zone
  location: 'global'
  tags: tags
}]

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in zones: {
  parent: privateZones[i]
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
  tags: tags
}]

// TODO: create private DNS zones and links per RFC-42.
