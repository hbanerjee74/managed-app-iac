targetScope = 'resourceGroup'

@description('Resource group name used for deterministic naming (RFC-64: resourceGroupName, same as mrgName). Defaults to current resource group name from ARM context.')
param resourceGroupName string = resourceGroup().name

@description('Azure region for deployment. Defaults to current resource group location from ARM context.')
param location string = resourceGroup().location

@description('Customer admin Entra object ID (RFC-64).')
param adminObjectId string

@description('Contact email for notifications (RFC-64).')
param contactEmail string

@description('Principal type for adminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param adminPrincipalType string = 'User'

@description('Services VNet CIDR block (RFC-64).')
param servicesVnetCidr string = '10.100.0.0/24'

@description('Customer IP ranges for WAF allowlist (RFC-64).')
@minLength(1)
param customerIpRanges array

@description('Publisher IP ranges for WAF allowlist (RFC-64).')
@minLength(1)
param publisherIpRanges array

@description('App Service Plan SKU (RFC-64 sku).')
@allowed([
  'P1v3'
  'P2v3'
  'P3v3'
])
param sku string = 'P1v3'

@description('AKS node size (RFC-64 nodeSize). Note: Parameter defined per RFC-64 but currently unused as AKS deployment is out of scope for PRD-30.')
@allowed([
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_D16s_v3'
])
param nodeSize string = 'Standard_D4s_v3'

@description('PostgreSQL compute tier (RFC-64 computeTier).')
@allowed([
  'GP_Standard_D2s_v3'
  'GP_Standard_D4s_v3'
])
param computeTier string = 'GP_Standard_D2s_v3'

@description('AI Services tier (RFC-64).')
@allowed([
  'S1'
  'S2'
  'S3'
])
param aiServicesTier string = 'S1'

@description('Log Analytics retention in days (RFC-64 retentionDays display).')
@minValue(30)
@maxValue(730)
param retentionDays int = 30

@description('Application Gateway capacity (RFC-64 appGwCapacity display).')
@minValue(1)
@maxValue(10)
param appGwCapacity int = 1

@description('Application Gateway SKU (RFC-64 appGwSku display).')
@allowed([
  'WAF_v2'
])
param appGwSku string = 'WAF_v2'

@description('PostgreSQL storage in GB (RFC-64 storageGB display).')
@minValue(32)
@maxValue(16384)
param storageGB int = 128

@description('PostgreSQL backup retention days (RFC-64 backupRetentionDays display).')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Optional tags: environment (dev/release/prod), owner, purpose, created (ISO8601).')
param environment string = ''
param owner string = ''
param purpose string = ''
param created string = ''

// Naming helper to generate deterministic per-resource nanoids.
module naming 'lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

var tags = union(
  empty(environment) ? {} : { environment: environment },
  empty(owner) ? {} : { owner: owner },
  empty(purpose) ? {} : { purpose: purpose },
  empty(created) ? {} : { created: created },
  empty(contactEmail) ? {} : { contactEmail: contactEmail }
)

// TODO: add remaining RFC-64 parameters as modules are implemented.

module diagnostics 'modules/diagnostics.bicep' = {
  name: 'diagnostics'
  params: {
    location: location
    retentionDays: retentionDays
    lawName: naming.outputs.names.law
    tags: tags
  }
}

module identity 'modules/identity.bicep' = {
  name: 'identity'
  dependsOn: [diagnostics]
  params: {
    location: location
    uamiName: naming.outputs.names.uami
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    lawName: naming.outputs.names.law
    tags: tags
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

module dns 'modules/dns.bicep' = {
  name: 'dns'
  params: {
    vnetName: naming.outputs.names.vnet
    tags: tags
  }
}

module kv 'modules/kv.bicep' = {
  name: 'kv'
  params: {
    location: location
    kvName: naming.outputs.names.kv
    subnetPeId: network.outputs.subnetPeId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peKvName: naming.outputs.names.peKv
    peKvDnsName: naming.outputs.names.peKvDns
    diagKvName: naming.outputs.names.diagKv
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageName: naming.outputs.names.storage
    subnetPeId: network.outputs.subnetPeId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peStBlobName: naming.outputs.names.peStBlob
    peStQueueName: naming.outputs.names.peStQueue
    peStTableName: naming.outputs.names.peStTable
    peStBlobDnsName: naming.outputs.names.peStBlobDns
    peStQueueDnsName: naming.outputs.names.peStQueueDns
    peStTableDnsName: naming.outputs.names.peStTableDns
    diagStName: naming.outputs.names.diagSt
    tags: tags
  }
}

module flowLogs 'modules/flow-logs.bicep' = {
  name: 'flow-logs'
  dependsOn: [network, storage, identity]
  params: {
    location: location
    vnetId: network.outputs.vnetId
    storageAccountId: storage.outputs.storageId
    vnetFlowLogName: naming.outputs.names.vnetFlowLog
    uamiId: identity.outputs.uamiId
    tags: tags
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    acrName: naming.outputs.names.acr
    subnetPeId: network.outputs.subnetPeId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peAcrName: naming.outputs.names.peAcr
    peAcrDnsName: naming.outputs.names.peAcrDns
    diagAcrName: naming.outputs.names.diagAcr
    tags: tags
  }
}

module data 'modules/data.bicep' = {
  name: 'data'
  params: {
    location: location
    psqlName: naming.outputs.names.psql
    computeTier: computeTier
    backupRetentionDays: backupRetentionDays
    storageGB: storageGB
    subnetPsqlId: network.outputs.subnetPsqlId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    lawId: diagnostics.outputs.lawId
    uamiClientId: identity.outputs.uamiClientId
    uamiId: identity.outputs.uamiId
    zoneIds: dns.outputs.zoneIds
    diagPsqlName: naming.outputs.names.diagPsql
    tags: tags
  }
}

module compute 'modules/compute.bicep' = {
  name: 'compute'
  params: {
    location: location
    sku: sku
    aspName: naming.outputs.names.asp
    appApiName: naming.outputs.names.appApi
    appUiName: naming.outputs.names.appUi
    funcName: naming.outputs.names.funcOps
    subnetAppsvcId: network.outputs.subnetAppsvcId
    subnetPeId: network.outputs.subnetPeId
    uamiId: identity.outputs.uamiId
    storageAccountName: naming.outputs.names.storage
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peAppApiName: naming.outputs.names.peAppApi
    peAppUiName: naming.outputs.names.peAppUi
    peFuncName: naming.outputs.names.peFunc
    peAppApiDnsName: naming.outputs.names.peAppApiDns
    peAppUiDnsName: naming.outputs.names.peAppUiDns
    peFuncDnsName: naming.outputs.names.peFuncDns
    diagAppApiName: naming.outputs.names.diagAppApi
    diagAppUiName: naming.outputs.names.diagAppUi
    diagFuncName: naming.outputs.names.diagFunc
    tags: tags
  }
}

module publicIp 'modules/public-ip.bicep' = {
  name: 'publicIp'
  params: {
    location: location
    pipName: naming.outputs.names.pipAgw
    tags: tags
  }
}

var wafPolicyName = '${naming.outputs.names.agw}-waf'

module wafPolicy 'modules/waf-policy.bicep' = {
  name: 'wafPolicy'
  params: {
    location: location
    wafPolicyName: wafPolicyName
    customerIpRanges: customerIpRanges
    publisherIpRanges: publisherIpRanges
    tags: tags
  }
}

module gateway 'modules/gateway.bicep' = {
  name: 'gateway'
  params: {
    location: location
    agwName: naming.outputs.names.agw
    pipId: publicIp.outputs.pipId
    wafPolicyId: wafPolicy.outputs.wafPolicyId
    subnetAppgwId: network.outputs.subnetAppgwId
    lawId: diagnostics.outputs.lawId
    appGwCapacity: appGwCapacity
    appGwSku: appGwSku
    diagAgwName: naming.outputs.names.diagAgw
    tags: tags
  }
}

module search 'modules/search.bicep' = {
  name: 'search'
  params: {
    location: location
    aiServicesTier: aiServicesTier
    searchName: naming.outputs.names.search
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    zoneIds: dns.outputs.zoneIds
    peSearchName: naming.outputs.names.peSearch
    peSearchDnsName: naming.outputs.names.peSearchDns
    diagSearchName: naming.outputs.names.diagSearch
    tags: tags
  }
}

module cognitiveServices 'modules/cognitive-services.bicep' = {
  name: 'cognitive-services'
  params: {
    location: location
    aiName: naming.outputs.names.ai
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    zoneIds: dns.outputs.zoneIds
    peAiName: naming.outputs.names.peAi
    peAiDnsName: naming.outputs.names.peAiDns
    diagAiName: naming.outputs.names.diagAi
    tags: tags
  }
}

module automation 'modules/automation.bicep' = {
  name: 'automation'
  params: {
    location: location
    automationName: naming.outputs.names.automation
    uamiId: identity.outputs.uamiId
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peAutomationName: naming.outputs.names.peAutomation
    peAutomationDnsName: naming.outputs.names.peAutomationDns
    diagAutomationName: naming.outputs.names.diagAutomation
    tags: tags
  }
}

module logic 'modules/logic.bicep' = {
  name: 'logic'
  params: {
    location: location
    logicName: naming.outputs.names.logic
    uamiId: identity.outputs.uamiId
    lawId: diagnostics.outputs.lawId
    diagLogicName: naming.outputs.names.diagLogic
    tags: tags
  }
}

output names object = naming.outputs.names
output lawId string = diagnostics.outputs.lawId
output lawWorkspaceId string = diagnostics.outputs.lawWorkspaceId
