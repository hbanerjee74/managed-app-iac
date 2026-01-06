targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Name for the Network Watcher.')
param networkWatcherName string

@description('Log Analytics workspace id for Traffic Analytics.')
param lawWorkspaceId string

@description('Log Analytics workspace resource id for Traffic Analytics.')
param lawId string

@description('Storage account resource id for NSG flow logs.')
param storageId string

@description('NSG IDs to enable flow logs for.')
param nsgAppgwId string
param nsgAksId string
param nsgAppsvcId string
param nsgPeId string

@description('Flow log resource names.')
param flowLogAppgwName string
param flowLogAksName string
param flowLogAppsvcName string
param flowLogPeName string

@description('Optional tags to apply.')
param tags object = {}

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-04-01' = {
  name: networkWatcherName
  location: location
  tags: tags
}

var trafficAnalytics = {
  enabled: true
  workspaceId: lawWorkspaceId
  workspaceRegion: location
  workspaceResourceId: lawId
  trafficAnalyticsInterval: 60
}

resource flowLogsAppgw 'Microsoft.Network/networkWatchers/flowLogs@2023-04-01' = {
  parent: networkWatcher
  name: flowLogAppgwName
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceId: nsgAppgwId
    storageId: storageId
    format: {
      type: 'JSON'
      version: 2
    }
    retentionPolicy: {
      enabled: true
      days: 7
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: trafficAnalytics
    }
  }
}

resource flowLogsAks 'Microsoft.Network/networkWatchers/flowLogs@2023-04-01' = {
  parent: networkWatcher
  name: flowLogAksName
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceId: nsgAksId
    storageId: storageId
    format: {
      type: 'JSON'
      version: 2
    }
    retentionPolicy: {
      enabled: true
      days: 7
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: trafficAnalytics
    }
  }
}

resource flowLogsAppsvc 'Microsoft.Network/networkWatchers/flowLogs@2023-04-01' = {
  parent: networkWatcher
  name: flowLogAppsvcName
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceId: nsgAppsvcId
    storageId: storageId
    format: {
      type: 'JSON'
      version: 2
    }
    retentionPolicy: {
      enabled: true
      days: 7
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: trafficAnalytics
    }
  }
}

resource flowLogsPe 'Microsoft.Network/networkWatchers/flowLogs@2023-04-01' = {
  parent: networkWatcher
  name: flowLogPeName
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceId: nsgPeId
    storageId: storageId
    format: {
      type: 'JSON'
      version: 2
    }
    retentionPolicy: {
      enabled: true
      days: 7
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: trafficAnalytics
    }
  }
}

output networkWatcherId string = networkWatcher.id
