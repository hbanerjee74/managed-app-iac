targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Bastion host name.')
param bastionName string

@description('Public IP name for Bastion.')
param pipBastionName string

@description('Subnet ID for Bastion (must be dedicated /26 or larger).')
param subnetBastionId string

@description('Optional tags to apply.')
param tags object = {}

// Public IP for Bastion
resource pipBastion 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipBastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Bastion Host
resource bastion 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: bastionName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: subnetBastionId
          }
          publicIPAddress: {
            id: pipBastion.id
          }
        }
      }
    ]
  }
}

output bastionId string = bastion.id
output bastionName string = bastion.name
