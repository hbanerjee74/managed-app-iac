targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

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

@description('Private endpoint name from naming helper.')
param peAcrName string

@description('Private DNS zone group name from naming helper.')
param peAcrDnsName string

@description('Diagnostic setting name from naming helper.')
param diagAcrName string

@description('Optional tags to apply.')
param tags object = {}

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

// Private Endpoint
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

// RBAC assignments
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

// Diagnostic settings
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

output acrId string = acr.id
output peAcrId string = peAcr.id

