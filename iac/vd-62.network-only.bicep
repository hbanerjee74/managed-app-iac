targetScope = 'resourceGroup'

@description('Seed used for deterministic naming (use same value as PRD-30 mrgName).')
param mrgName string

@description('Deployment location.')
param location string

@description('Services VNet CIDR block (RFC-64). Must be /16-/24.')
param servicesVnetCidr string

@description('Optional tags to apply.')
param tags object = {}

@description('Enable NSG flow logs (requires existing LAW + Storage).')
param enableFlowLogs bool = false

@description('Existing Log Analytics workspace resource id (required if enableFlowLogs=true).')
param lawId string = ''

@description('Existing Log Analytics workspace workspaceId (required if enableFlowLogs=true).')
param lawWorkspaceId string = ''

@description('Existing storage account name for NSG flow logs (required if enableFlowLogs=true).')
param storageAccountName string = ''

module naming 'lib/naming.bicep' = {
  name: 'naming'
  scope: subscription()
  params: {
    resourceGroupName: mrgName
    purpose: 'platform'
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    servicesVnetCidr: servicesVnetCidr
    vnetName: naming.outputs.names.vnet
    nsgAppgwName: naming.outputs.names.nsgAppgw
    nsgAksName: naming.outputs.names.nsgAks
    nsgAppsvcName: naming.outputs.names.nsgAppsvc
    nsgPeName: naming.outputs.names.nsgPe
    tags: tags
  }
}

module networkFlowLogs 'modules/network.flowlogs.bicep' = if (enableFlowLogs) {
  name: 'network-flowlogs'
  dependsOn: [network]
  params: {
    location: location
    networkWatcherName: naming.outputs.names.networkWatcher
    lawWorkspaceId: lawWorkspaceId
    lawId: lawId
    storageId: resourceId('Microsoft.Storage/storageAccounts', storageAccountName)
    nsgAppgwId: resourceId('Microsoft.Network/networkSecurityGroups', naming.outputs.names.nsgAppgw)
    nsgAksId: resourceId('Microsoft.Network/networkSecurityGroups', naming.outputs.names.nsgAks)
    nsgAppsvcId: resourceId('Microsoft.Network/networkSecurityGroups', naming.outputs.names.nsgAppsvc)
    nsgPeId: resourceId('Microsoft.Network/networkSecurityGroups', naming.outputs.names.nsgPe)
    flowLogAppgwName: naming.outputs.names.flowLogAppgw
    flowLogAksName: naming.outputs.names.flowLogAks
    flowLogAppsvcName: naming.outputs.names.flowLogAppsvc
    flowLogPeName: naming.outputs.names.flowLogPe
    tags: tags
  }
}

output names object = naming.outputs.names
output vnetId string = network.outputs.vnetId
output subnetAppgwId string = network.outputs.subnetAppgwId
output subnetAksId string = network.outputs.subnetAksId
output subnetAppsvcId string = network.outputs.subnetAppsvcId
output subnetPeId string = network.outputs.subnetPeId
output subnetPsqlId string = network.outputs.subnetPsqlId
