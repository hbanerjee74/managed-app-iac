targetScope = 'resourceGroup'

@description('Name of the Services VNet to link.')
param vnetName string

@description('Tags to apply.')
param tags object

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

// Create zones only once; expose ids so dependents can link deterministically.
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
  dependsOn: [
    vnet
    privateZones
  ]
}]

output zoneIds object = {
  vault: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
  postgres: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.postgres.database.azure.com')
  blob: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${storageSuffix}')
  queue: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.queue.${storageSuffix}')
  table: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.table.${storageSuffix}')
  acr: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.azurecr.io')
  appsvc: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.azurewebsites.net')
  search: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.search.windows.net')
  ai: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.cognitiveservices.azure.com')
  automation: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.azure-automation.net')
  internal: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'vibedata.internal')
}

output vnetLinkIds object = {
  vault: vnetLinks[0].id
  postgres: vnetLinks[1].id
  blob: vnetLinks[2].id
  queue: vnetLinks[3].id
  table: vnetLinks[4].id
  acr: vnetLinks[5].id
  appsvc: vnetLinks[6].id
  search: vnetLinks[7].id
  ai: vnetLinks[8].id
  automation: vnetLinks[9].id
  internal: vnetLinks[10].id
}
