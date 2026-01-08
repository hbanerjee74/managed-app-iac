targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Public IP name.')
param pipName string

@description('Optional tags to apply.')
param tags object = {}

resource pip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

output pipId string = pip.id

