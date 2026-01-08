targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('AI Foundry (Cognitive Services) name.')
param aiName string

@description('Private Endpoints subnet ID.')
param subnetPeId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object


@description('Private endpoint name from naming helper.')
param peAiName string

@description('Private DNS zone group name from naming helper.')
param peAiDnsName string

@description('Diagnostic setting name from naming helper.')
param diagAiName string

@description('Optional tags to apply.')
param tags object = {}

resource ai 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aiName
  location: location
  kind: 'CognitiveServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: aiName  // Required for private endpoints
    publicNetworkAccess: 'disabled'
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

// Diagnostic settings
// Note: Cognitive Services don't support AuditEvent log category.
// Only metrics are supported for Cognitive Services diagnostic settings.
resource aiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagAiName
  scope: ai
  properties: {
    workspaceId: lawId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// RBAC assignments moved to consolidated rbac.bicep module

output aiId string = ai.id
output peAiId string = peAi.id

