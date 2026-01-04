targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('App Service Plan SKU (RFC-64 sku).')
param sku string

@description('App Service Plan name.')
param aspName string

@description('API App name.')
param appApiName string

@description('UI App name.')
param appUiName string

@description('Function App name.')
param funcName string

@description('App Service VNet integration subnet id.')
param subnetAppsvcId string

@description('Private Endpoints subnet ID.')
param subnetPeId string

@description('User-assigned managed identity resource id.')
param uamiId string

@description('Storage account name for Function runtime state (identity-based).')
param storageAccountName string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object
@description('Optional tags to apply.')
param tags object = {}

var storageSuffix = environment().suffixes.storage
var storageBlobUri = 'https://${storageAccountName}.blob.${storageSuffix}'
var storageQueueUri = 'https://${storageAccountName}.queue.${storageSuffix}'

resource asp 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: aspName
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: sku
    tier: 'PremiumV3'
  }
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

var defaultContainer = 'mcr.microsoft.com/azuredocs/aci-helloworld:latest'

resource appApi 'Microsoft.Web/sites@2023-12-01' = {
  name: appApiName
  location: location
  kind: 'app,linux,container'
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    serverFarmId: asp.id
    virtualNetworkSubnetId: subnetAppsvcId
    siteConfig: {
      linuxFxVersion: 'DOCKER|${defaultContainer}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: true
      vnetRouteAllEnabled: true
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictionsDefaultAction: 'Deny'
    }
  }
}

resource appUi 'Microsoft.Web/sites@2023-12-01' = {
  name: appUiName
  location: location
  kind: 'app,linux,container'
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    serverFarmId: asp.id
    virtualNetworkSubnetId: subnetAppsvcId
    siteConfig: {
      linuxFxVersion: 'DOCKER|${defaultContainer}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: true
      vnetRouteAllEnabled: true
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictionsDefaultAction: 'Deny'
    }
  }
}

resource func 'Microsoft.Web/sites@2023-12-01' = {
  name: funcName
  location: location
  kind: 'functionapp,linux,container'
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    serverFarmId: asp.id
    virtualNetworkSubnetId: subnetAppsvcId
    siteConfig: {
      linuxFxVersion: 'DOCKER|${defaultContainer}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: true
      vnetRouteAllEnabled: true
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictionsDefaultAction: 'Deny'
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storageBlobUri
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: storageQueueUri
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'ManagedIdentity'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'custom'
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
      ]
    }
  }
}

// Private Endpoints for inbound
resource peAppApi 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${appApi.name}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'appapi-conn'
        properties: {
          groupIds: [
            'sites'
          ]
          privateLinkServiceId: appApi.id
        }
      }
    ]
  }
}

resource peAppApiDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peAppApi
  name: 'appapi-dns'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.azurewebsites.net'
        properties: {
          privateDnsZoneId: zoneIds.appsvc
        }
      }
    ]
  }
}

resource peAppUi 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${appUi.name}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'appui-conn'
        properties: {
          groupIds: [
            'sites'
          ]
          privateLinkServiceId: appUi.id
        }
      }
    ]
  }
}

resource peAppUiDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peAppUi
  name: 'appui-dns'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.azurewebsites.net'
        properties: {
          privateDnsZoneId: zoneIds.appsvc
        }
      }
    ]
  }
}

resource peFunc 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${func.name}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetPeId
    }
    privateLinkServiceConnections: [
      {
        name: 'func-conn'
        properties: {
          groupIds: [
            'sites'
          ]
          privateLinkServiceId: func.id
        }
      }
    ]
  }
}

resource peFuncDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: peFunc
  name: 'func-dns'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.azurewebsites.net'
        properties: {
          privateDnsZoneId: zoneIds.appsvc
        }
      }
    ]
  }
}

output appApiId string = appApi.id
output appUiId string = appUi.id
output funcId string = func.id

resource appApiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-law-appapi'
  scope: appApi
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
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

resource appUiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-law-appui'
  scope: appUi
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
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

resource funcDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-law-func'
  scope: func
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'FunctionAppLogs'
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

// TODO: deploy App Service Plan, Web Apps, and Functions with private endpoints.
