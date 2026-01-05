targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Key Vault name.')
param kvName string

@description('Storage Account name.')
param storageName string

@description('Container Registry name.')
param acrName string

@description('Private Endpoints subnet ID.')
param subnetPeId string

@description('Principal ID of the UAMI for RBAC.')
param uamiPrincipalId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object

@description('Private endpoint names from naming helper.')
param peKvName string
param peStBlobName string
param peStQueueName string
param peStTableName string
param peAcrName string

@description('Private DNS zone group names from naming helper.')
param peKvDnsName string
param peStBlobDnsName string
param peStQueueDnsName string
param peStTableDnsName string
param peAcrDnsName string

@description('Diagnostic setting names from naming helper.')
param diagKvName string
param diagStName string
param diagAcrName string

@description('Optional tags to apply.')
param tags object = {}

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

resource st 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    defaultToOAuthAuthentication: true
  }
}

// Storage data plane resources
resource artifactsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${st.name}/default/artifacts'
  properties: {
    publicAccess: 'None'
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    metadata: {
      tier: 'Cool'
    }
  }
}

resource queues 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = [
  for q in [
    'health-notifications-queue'
    'update-notifications-queue'
    'monitor-alerts-queue'
  ]: {
    name: '${st.name}/default/${q}'
    properties: {
      metadata: {}
    }
  }
]

resource tables 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-01-01' = [
  for t in [
    'engineHistory'
    'engineDlq'
  ]: {
    name: '${st.name}/default/${t}'
  }
]

resource acr 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Disabled'
    dataEndpointEnabled: false
  }
}

// Private Endpoints
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
}

resource peStBlob 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peStBlobName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'st-blob-conn'
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: st.id
        }
      }
    ]
  }
}

resource peStBlobDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peStBlob
  name: peStBlobDnsName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: blobZone
        properties: {
          privateDnsZoneId: zoneIds.blob
        }
      }
    ]
  }
}

resource peStQueue 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peStQueueName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'st-queue-conn'
        properties: {
          groupIds: [
            'queue'
          ]
          privateLinkServiceId: st.id
        }
      }
    ]
  }
}

resource peStQueueDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peStQueue
  name: peStQueueDnsName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: queueZone
        properties: {
          privateDnsZoneId: zoneIds.queue
        }
      }
    ]
  }
}

resource peStTable 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peStTableName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'st-table-conn'
        properties: {
          groupIds: [
            'table'
          ]
          privateLinkServiceId: st.id
        }
      }
    ]
  }
}

resource peStTableDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peStTable
  name: peStTableDnsName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: tableZone
        properties: {
          privateDnsZoneId: zoneIds.table
        }
      }
    ]
  }
}

resource peAcr 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peAcrName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'acr-conn'
        properties: {
          groupIds: [
            'registry'
          ]
          privateLinkServiceId: acr.id
        }
      }
    ]
  }
}

resource peAcrDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peAcr
  name: peAcrDnsName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.azurecr.io'
        properties: {
          privateDnsZoneId: zoneIds.acr
        }
      }
    ]
  }
}

// RBAC assignments per resource
resource kvSecretsOfficer 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, uamiPrincipalId, 'kv-secret-officer')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource stBlobContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(st.id, uamiPrincipalId, 'st-blob-data-contrib')
  scope: st
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource stQueueContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(st.id, uamiPrincipalId, 'st-queue-data-contrib')
  scope: st
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '19e7f393-1728-4e7a-9c12-054fda5c492f') // Storage Queue Data Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, uamiPrincipalId, 'acr-pull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource acrPush 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, uamiPrincipalId, 'acr-push')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec') // AcrPush
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output kvId string = kv.id
output storageId string = st.id
output acrId string = acr.id

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
}

resource stDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagStName
  scope: st
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
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
}

resource acrDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagAcrName
  scope: acr
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
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
}

// TODO: deploy Key Vault, Storage, and Container Registry with private access.
var storageSuffix = environment().suffixes.storage
var blobZone = 'privatelink.blob.${storageSuffix}'
var queueZone = 'privatelink.queue.${storageSuffix}'
var tableZone = 'privatelink.table.${storageSuffix}'
