targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('AI Services tier.')
param aiServicesTier string

@description('AI Search service name.')
param searchName string

@description('AI Foundry (Cognitive Services) name.')
param aiName string

@description('Private Endpoints subnet ID.')
param subnetPeId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object

@description('Principal ID of the UAMI for RBAC (optional).')
param uamiPrincipalId string = ''

@description('Private endpoint names from naming helper.')
param peSearchName string
param peAiName string

@description('Private DNS zone group names from naming helper.')
param peSearchDnsName string
param peAiDnsName string

@description('Diagnostic setting names from naming helper.')
param diagSearchName string
param diagAiName string

@description('Optional tags to apply.')
param tags object = {}

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

resource ai 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aiName
  location: location
  kind: 'CognitiveServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  properties: {
    publicNetworkAccess: 'disabled'
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
}

resource peAi 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peAiName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'ai-conn'
        properties: {
          groupIds: [
            'account'
          ]
          privateLinkServiceId: ai.id
        }
      }
    ]
  }
}

resource peAiDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peAi
  name: peAiDnsName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.cognitiveservices.azure.com'
        properties: {
          privateDnsZoneId: zoneIds.ai
        }
      }
    ]
  }
}

output searchId string = search.id
output aiId string = ai.id

resource searchDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSearchName
  scope: search
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'AllMetrics'
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

resource aiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagAiName
  scope: ai
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

// RBAC assignments
resource aiContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(uamiPrincipalId)) {
  name: guid(ai.id, uamiPrincipalId, 'ai-contrib')
  scope: ai
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource searchContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(uamiPrincipalId)) {
  name: guid(search.id, uamiPrincipalId, 'search-contrib')
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772') // Search Service Contributor
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}
