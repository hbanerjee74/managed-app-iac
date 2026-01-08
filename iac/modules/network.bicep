targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Services VNet CIDR block. Must be /16-/21 for /25 subnet scheme.')
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

// Validate CIDR format and prefix length using parseCidr
// parseCidr will fail if CIDR format is invalid
var parsedCidr = parseCidr(servicesVnetCidr)
var vnetPrefixLength = parsedCidr.cidr

// Validate prefix length range for /25 subnets with net numbers up to 8.
// Requires at least 9 /25 subnets -> vnet prefix must be /21 or larger network (<= /21).
// Use conditional to enforce validation - if prefix is out of range, subnetNewBits becomes invalid
// This will cause cidrSubnet() to fail during deployment
var cidrPrefixValid = vnetPrefixLength >= 16 && vnetPrefixLength <= 21

// Calculate subnet parameters: use /25 consistently with gaps for growth
// Subnet numbers: [0, 1, 2, 4, 8] - PostgreSQL uses #1, private endpoints uses #2, leaves gaps at 3 and 5-7,9+ for future expansion
// Note: Changed private endpoints from #12 to #2 to avoid validation issues with /20 networks
// If prefix is out of range, subnetNewBits will be invalid (negative or > 8) causing cidrSubnet to fail
var subnetNewBits = cidrPrefixValid ? (25 - vnetPrefixLength) : -1

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
          // /25 subnet #0 - Application Gateway
          addressPrefix: cidrSubnet(servicesVnetCidr, subnetNewBits, 0)
          networkSecurityGroup: {
            id: nsgAppgw.id
          }
        }
      }
      {
        name: 'snet-psql'
        properties: {
          // /25 subnet #1 - PostgreSQL Flexible Server (subnet #2 used by private endpoints, gap at 3 before aks subnet #4)
          addressPrefix: cidrSubnet(servicesVnetCidr, subnetNewBits, 1)
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
        name: 'snet-aks'
        properties: {
          // /25 subnet #4 - AKS Nodes (gaps at 2,3 for growth, subnet #1 used by PostgreSQL)
          addressPrefix: cidrSubnet(servicesVnetCidr, subnetNewBits, 4)
          networkSecurityGroup: {
            id: nsgAks.id
          }
        }
      }
      {
        name: 'snet-appsvc'
        properties: {
          // /25 subnet #8 - App Service Integration (gaps at 5,6,7 for growth)
          addressPrefix: cidrSubnet(servicesVnetCidr, subnetNewBits, 8)
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
          // /25 subnet #2 - Private Endpoints (moved from #12 to avoid validation issues with /20 networks)
          addressPrefix: cidrSubnet(servicesVnetCidr, subnetNewBits, 2)
          networkSecurityGroup: {
            id: nsgPe.id
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
output subnetAksId string = vnet.properties.subnets[2].id   // subnet #4
output subnetAppsvcId string = vnet.properties.subnets[3].id // subnet #8
output subnetPeId string = vnet.properties.subnets[4].id     // subnet #2
output subnetAppgwPrefix string = vnet.properties.subnets[0].properties.addressPrefix
output subnetPsqlPrefix string = vnet.properties.subnets[1].properties.addressPrefix
output subnetAksPrefix string = vnet.properties.subnets[2].properties.addressPrefix
output subnetAppsvcPrefix string = vnet.properties.subnets[3].properties.addressPrefix
output subnetPePrefix string = vnet.properties.subnets[4].properties.addressPrefix

// TODO: deploy VNet, subnets, NSGs, and private endpoints per RFC-42.
// Note: VNet flow logs are deployed in a separate module (flow-logs.bicep) to avoid circular dependency with storage.
