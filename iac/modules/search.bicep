targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('AI Services tier.')
param aiServicesTier string

@description('AI Search service name.')
param searchName string

@description('Private Endpoints subnet ID.')
param subnetPeId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object


@description('Private endpoint name from naming helper.')
param peSearchName string

@description('Private DNS zone group name from naming helper.')
param peSearchDnsName string

@description('Diagnostic setting name from naming helper.')
param diagSearchName string

@description('Tags to apply.')
param tags object

resource search 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchName
  location: location
  tags: tags
  sku: {
    name: aiServicesTier
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    publicNetworkAccess: 'disabled'
    hostingMode: 'default'
  }
}

resource peSearch 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peSearchName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'search-conn'
        properties: {
          groupIds: [
            'searchService'
          ]
          privateLinkServiceId: search.id
        }
      }
    ]
  }
  dependsOn: [
    search
  ]
}

resource peSearchDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peSearch
  name: peSearchDnsName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.search.windows.net'
        properties: {
          privateDnsZoneId: zoneIds.search
        }
      }
    ]
  }
  dependsOn: [
    peSearch
  ]
}

resource searchDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSearchName
  scope: search
  properties: {
    workspaceId: lawId
    // Azure AI Search only supports metrics, not logs
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: [
    search
  ]
}

// RBAC assignments moved to consolidated rbac.bicep module

output searchId string = search.id
output peSearchId string = peSearch.id

