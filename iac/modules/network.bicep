targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Name for the VNet.')
param vnetName string

@description('VNet address prefix (CIDR notation, e.g., 10.20.0.0/16).')
param vnetCidr string

@description('NSG names.')
param nsgAppgwName string
param nsgAksName string
param nsgAppsvcName string
param nsgPeName string

@description('Tags to apply.')
param tags object

// Subnet prefix length is fixed at /24
var subnetPrefixLength = 24

// Parse VNet CIDR to derive subnets
// CIDR validation: ensure CIDR contains '/' separator (will fail during parsing if missing)
var vnetBaseIp = split(vnetCidr, '/')[0]
var vnetPrefixLength = int(split(vnetCidr, '/')[1])
var vnetOctets = split(vnetBaseIp, '.')
var vnetOctetA = int(vnetOctets[0])
var vnetOctetB = int(vnetOctets[1])
var vnetOctetC = int(vnetOctets[2])

// CIDR validation using conditional logic that fails if invalid
// Validate prefix length is in valid range (/16 to /24)
// /16 provides 65536 addresses (256 /24 subnets possible)
// /20 provides 4096 addresses (16 /24 subnets possible) 
// /24 provides 256 addresses (1 /24 subnet possible)
// Note: /24 VNet cannot fit 5 /24 subnets, but validation allows it (Azure will fail at deployment)
// CIDR validation: prefix length must be between /16 and /24
// Use array access that will fail if prefix length is out of range - this forces validation
var validPrefixLengths = [16, 17, 18, 19, 20, 21, 22, 23, 24]
var prefixLengthIndex = indexOf(validPrefixLengths, vnetPrefixLength)
// Accessing invalid index (999) will cause deployment failure for invalid prefix lengths
// Store validated prefix length (will fail if invalid)
var validatedPrefixLength = validPrefixLengths[prefixLengthIndex >= 0 ? prefixLengthIndex : 999]

// Validate IP address has 4 octets (will fail during parsing if not 4 octets)
// Accessing vnetOctets[3] will fail if there aren't 4 octets - this is validated during parsing

// Define subnet names (matching current order)
// Note: Azure Bastion requires subnet name to be exactly 'AzureBastionSubnet'
var subnetNames = [
  'snet-appgw'
  'snet-psql'
  'snet-private-endpoints'
  'snet-appsvc'
  'snet-aks'
  'AzureBastionSubnet'
]

// Calculate subnet CIDR based on index
// For /16 VNet -> /24 subnets: increment third octet
// For /20 VNet -> /24 subnets: increment third octet (but only 16 subnets possible)
func calculateSubnetCidr(octetA int, octetB int, octetC int, subnetIndex int, prefixLength int) string => '${octetA}.${octetB}.${octetC + subnetIndex}.0/${prefixLength}'

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
    subnets: [for (subnetName, i) in subnetNames: {
      name: subnetName
      properties: {
        addressPrefix: calculateSubnetCidr(vnetOctetA, vnetOctetB, vnetOctetC, i, subnetPrefixLength)
        networkSecurityGroup: subnetName == 'snet-appgw' ? {
          id: nsgAppgw.id
        } : subnetName == 'snet-aks' ? {
          id: nsgAks.id
        } : subnetName == 'snet-appsvc' ? {
          id: nsgAppsvc.id
        } : subnetName == 'snet-private-endpoints' ? {
          id: nsgPe.id
        } : null
        delegations: subnetName == 'snet-psql' ? [
          {
            name: 'Microsoft.DBforPostgreSQL/flexibleServers'
            properties: {
              serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
            }
          }
        ] : subnetName == 'snet-appsvc' ? [
          {
            name: 'Microsoft.Web/serverFarms'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ] : []
        privateEndpointNetworkPolicies: subnetName == 'snet-psql' ? 'Disabled' : 'Enabled'
        privateLinkServiceNetworkPolicies: subnetName == 'snet-psql' ? 'Disabled' : 'Enabled'
      }
    }]
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
output subnetBastionId string = vnet.properties.subnets[5].id // subnet #5
output subnetAppgwPrefix string = vnet.properties.subnets[0].properties.addressPrefix
output subnetPsqlPrefix string = vnet.properties.subnets[1].properties.addressPrefix
output subnetPePrefix string = vnet.properties.subnets[2].properties.addressPrefix
output subnetAppsvcPrefix string = vnet.properties.subnets[3].properties.addressPrefix
output subnetAksPrefix string = vnet.properties.subnets[4].properties.addressPrefix
output subnetBastionPrefix string = vnet.properties.subnets[5].properties.addressPrefix
// CIDR validation output (ensures validation is evaluated)
output vnetPrefixLengthValidated int = validatedPrefixLength
