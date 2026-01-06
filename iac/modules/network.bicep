targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Services VNet CIDR block. Must be /16-/24 per RFC-64.')
param servicesVnetCidr string

@description('Name for the VNet.')
param vnetName string

@description('NSG names.')
param nsgAppgwName string
param nsgAksName string
param nsgAppsvcName string
param nsgPeName string

@description('Optional tags to apply.')
param tags object = {}

var vnetPrefix = int(split(servicesVnetCidr, '/')[1])

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        servicesVnetCidr
      ]
    }
    subnets: [
      {
        name: 'snet-appgw'
        properties: {
          // /27 derived from base
          addressPrefix: cidrSubnet(servicesVnetCidr, 27 - vnetPrefix, 0)
          networkSecurityGroup: {
            id: nsgAppgw.id
          }
        }
      }
      {
        name: 'snet-aks'
        properties: {
          // /25 next block after appgw
          addressPrefix: cidrSubnet(servicesVnetCidr, 25 - vnetPrefix, 1)
          networkSecurityGroup: {
            id: nsgAks.id
          }
        }
      }
      {
        name: 'snet-appsvc'
        properties: {
          // /28 app service delegated
          addressPrefix: cidrSubnet(servicesVnetCidr, 28 - vnetPrefix, 2)
          delegations: [
            {
              name: 'Microsoft.Web/serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsgAppsvc.id
          }
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          // /28 for PEs
          addressPrefix: cidrSubnet(servicesVnetCidr, 28 - vnetPrefix, 3)
          networkSecurityGroup: {
            id: nsgPe.id
          }
        }
      }
      {
        name: 'snet-psql'
        properties: {
          // /28 delegated to PostgreSQL flexible server
          addressPrefix: cidrSubnet(servicesVnetCidr, 28 - vnetPrefix, 4)
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL/flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource nsgAppgw 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgAppgwName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-443-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-GatewayManager'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-VNet-Inbound'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-All-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}

resource nsgAks 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgAksName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-VNet-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-All-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}

resource nsgAppsvc 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgAppsvcName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-VNet-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-All-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}

resource nsgPe 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgPeName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-VNet-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 210
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-VNet-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Deny-Internet-Outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output subnetAppgwId string = vnet.properties.subnets[0].id
output subnetAksId string = vnet.properties.subnets[1].id
output subnetAppsvcId string = vnet.properties.subnets[2].id
output subnetPeId string = vnet.properties.subnets[3].id
output subnetPsqlId string = vnet.properties.subnets[4].id
output subnetAppgwPrefix string = vnet.properties.subnets[0].properties.addressPrefix
output subnetAksPrefix string = vnet.properties.subnets[1].properties.addressPrefix
output subnetAppsvcPrefix string = vnet.properties.subnets[2].properties.addressPrefix
output subnetPePrefix string = vnet.properties.subnets[3].properties.addressPrefix
output subnetPsqlPrefix string = vnet.properties.subnets[4].properties.addressPrefix

// TODO: deploy VNet, subnets, NSGs, and private endpoints per RFC-42.
