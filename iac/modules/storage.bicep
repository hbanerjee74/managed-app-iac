targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Storage Account name.')
param storageName string

@description('Private Endpoints subnet ID.')
param subnetPeId string


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

@description('Tags to apply.')
param tags object

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
  dependsOn: [
    st
  ]
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
  dependsOn: [
    peStBlob
  ]
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
  dependsOn: [
    st
  ]
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
  dependsOn: [
    peStQueue
  ]
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
  dependsOn: [
    st
  ]
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
  dependsOn: [
    peStTable
  ]
}

// RBAC assignments moved to consolidated rbac.bicep module

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
  dependsOn: [
    st
  ]
}

output storageId string = st.id
output peStBlobId string = peStBlob.id
output peStQueueId string = peStQueue.id
output peStTableId string = peStTable.id

