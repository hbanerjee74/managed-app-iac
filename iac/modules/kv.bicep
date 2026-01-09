targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Key Vault name.')
param kvName string

@description('Private Endpoints subnet ID.')
param subnetPeId string


@description('Log Analytics Workspace resource ID.')
param lawId string

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object

@description('Private endpoint name from naming helper.')
param peKvName string

@description('Private DNS zone group name from naming helper.')
param peKvDnsName string

@description('Diagnostic setting name from naming helper.')
param diagKvName string

@description('Tags to apply.')
param tags object

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Private Endpoint
resource peKv 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peKvName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-conn'
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: kv.id
        }
      }
    ]
  }
  dependsOn: [
    kv
  ]
}

resource peKvDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peKv
  name: peKvDnsName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.vaultcore.azure.net'
        properties: {
          privateDnsZoneId: zoneIds.vault
        }
      }
    ]
  }
  dependsOn: [
    peKv
  ]
}

// RBAC assignments moved to consolidated rbac.bicep module

// Diagnostic settings
resource kvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagKvName
  scope: kv
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: [
    kv
  ]
}

output kvId string = kv.id
output peKvId string = peKv.id

