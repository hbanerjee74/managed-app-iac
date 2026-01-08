targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Name for the VNet.')
param vnetName string

@description('NSG names.')
param nsgAppgwName string
param nsgAksName string
param nsgAppsvcName string
param nsgPeName string

@description('Optional tags to apply.')
param tags object = {}

// Hardcoded VNet and subnet CIDRs
// Note: VNet and subnet CIDRs are hardcoded to simplify deployment and avoid Azure cidrSubnet limitations.
// VNet: 10.20.0.0/16
// Subnets: /24 (256 addresses each)
//   - 10.20.0.0/24: Application Gateway
//   - 10.20.1.0/24: PostgreSQL Flexible Server
//   - 10.20.2.0/24: Private Endpoints
//   - 10.20.3.0/24: App Service Integration
//   - 10.20.4.0/24: AKS Nodes
// TODO: Consider making CIDRs configurable via parameters if VNet peering or different address spaces are needed
var vnetCidr = '10.20.0.0/16'
var subnetAppgwCidr = '10.20.0.0/24'      // Subnet #0 - Application Gateway
var subnetPsqlCidr = '10.20.1.0/24'        // Subnet #1 - PostgreSQL
var subnetPeCidr = '10.20.2.0/24'          // Subnet #2 - Private Endpoints
var subnetAppsvcCidr = '10.20.3.0/24'       // Subnet #3 - App Service
var subnetAksCidr = '10.20.4.0/24'         // Subnet #4 - AKS

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
    subnets: [
      {
        name: 'snet-appgw'
        properties: {
          addressPrefix: subnetAppgwCidr
          networkSecurityGroup: {
            id: nsgAppgw.id
          }
        }
      }
      {
        name: 'snet-psql'
        properties: {
          addressPrefix: subnetPsqlCidr
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
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: subnetPeCidr
          networkSecurityGroup: {
            id: nsgPe.id
          }
        }
      }
      {
        name: 'snet-appsvc'
        properties: {
          addressPrefix: subnetAppsvcCidr
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
        name: 'snet-aks'
        properties: {
          addressPrefix: subnetAksCidr
          networkSecurityGroup: {
            id: nsgAks.id
          }
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
output subnetAppgwId string = vnet.properties.subnets[0].id  // subnet #0
output subnetPsqlId string = vnet.properties.subnets[1].id   // subnet #1
output subnetPeId string = vnet.properties.subnets[2].id     // subnet #2
output subnetAppsvcId string = vnet.properties.subnets[3].id // subnet #3
output subnetAksId string = vnet.properties.subnets[4].id    // subnet #4
output subnetAppgwPrefix string = vnet.properties.subnets[0].properties.addressPrefix
output subnetPsqlPrefix string = vnet.properties.subnets[1].properties.addressPrefix
output subnetPePrefix string = vnet.properties.subnets[2].properties.addressPrefix
output subnetAppsvcPrefix string = vnet.properties.subnets[3].properties.addressPrefix
output subnetAksPrefix string = vnet.properties.subnets[4].properties.addressPrefix

// TODO: deploy VNet, subnets, NSGs, and private endpoints per RFC-42.
// Note: VNet flow logs are deployed in a separate module (flow-logs.bicep) to avoid circular dependency with storage.
