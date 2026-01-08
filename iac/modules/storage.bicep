targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Storage Account name.')
param storageName string

@description('Private Endpoints subnet ID.')
param subnetPeId string

@description('Principal ID of the UAMI for RBAC.')
param uamiPrincipalId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object

@description('Private endpoint names from naming helper.')
param peStBlobName string
param peStQueueName string
param peStTableName string

@description('Private DNS zone group names from naming helper.')
param peStBlobDnsName string
param peStQueueDnsName string
param peStTableDnsName string

@description('Diagnostic setting name from naming helper.')
param diagStName string

@description('Optional tags to apply.')
param tags object = {}

var storageSuffix = environment().suffixes.storage
var blobZone = 'privatelink.blob.${storageSuffix}'
var queueZone = 'privatelink.queue.${storageSuffix}'
var tableZone = 'privatelink.table.${storageSuffix}'

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

// Private Endpoints
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

// RBAC assignments
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
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource stTableContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(st.id, uamiPrincipalId, 'st-table-data-contrib')
  scope: st
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic settings
// Note: Storage Accounts don't support StorageRead/StorageWrite/StorageDelete log categories.
// Only metrics are supported for Storage Accounts diagnostic settings.
resource stDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagStName
  scope: st
  properties: {
    workspaceId: lawId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

output storageId string = st.id
output peStBlobId string = peStBlob.id
output peStQueueId string = peStQueue.id
output peStTableId string = peStTable.id

