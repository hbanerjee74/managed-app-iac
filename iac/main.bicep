targetScope = 'subscription'

@description('Existing resource group where all resources will be deployed.')
param resourceGroupName string

@description('Azure region for deployment.')
param location string

@description('Customer admin Entra object ID (RFC-64).')
param adminObjectId string

@description('Principal type for adminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param adminPrincipalType string = 'User'

@description('Services VNet CIDR block (RFC-64).')
param servicesVnetCidr string

@description('Customer IP ranges for WAF allowlist (RFC-64).')
param customerIpRanges array

@description('Publisher IP ranges for WAF allowlist (RFC-64).')
param publisherIpRanges array

@description('App Service Plan SKU (RFC-64).')
param appServicePlanSku string

@description('PostgreSQL compute tier (RFC-64).')
param postgresComputeTier string

@description('AI Services tier (RFC-64).')
param aiServicesTier string

@description('Log Analytics retention in days.')
param lawRetentionDays int

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
  empty(created) ? {} : { created: created }
)

// TODO: add remaining RFC-64 parameters as modules are implemented.

resource deploymentRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceGroupName
}

module diagnostics 'modules/diagnostics.bicep' = {
  name: 'diagnostics'
  scope: deploymentRg
  params: {
    location: location
    lawRetentionDays: lawRetentionDays
    lawName: naming.outputs.names.law
    tags: tags
  }
}

module identity 'modules/identity.bicep' = {
  name: 'identity'
  scope: deploymentRg
  params: {
    location: location
    uamiName: naming.outputs.names.uami
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: deploymentRg
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
  scope: deploymentRg
  params: {
    vnetName: naming.outputs.names.vnet
    tags: tags
  }
}

module security 'modules/security.bicep' = {
  name: 'security'
  scope: deploymentRg
  params: {
    location: location
    kvName: naming.outputs.names.kv
    storageName: naming.outputs.names.storage
    acrName: naming.outputs.names.acr
    subnetPeId: network.outputs.subnetPeId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    lawId: diagnostics.outputs.lawId
    tags: tags
  }
}

module data 'modules/data.bicep' = {
  name: 'data'
  scope: deploymentRg
  params: {
    location: location
    psqlName: naming.outputs.names.psql
    postgresComputeTier: postgresComputeTier
    subnetPsqlId: network.outputs.subnetPsqlId
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    lawId: diagnostics.outputs.lawId
    uamiClientId: identity.outputs.uamiClientId
    uamiId: identity.outputs.uamiId
    tags: tags
  }
}

module compute 'modules/compute.bicep' = {
  name: 'compute'
  scope: deploymentRg
  params: {
    location: location
    appServicePlanSku: appServicePlanSku
    aspName: naming.outputs.names.asp
    appApiName: naming.outputs.names.appApi
    appUiName: naming.outputs.names.appUi
    funcName: naming.outputs.names.funcOps
    subnetAppsvcId: network.outputs.subnetAppsvcId
    subnetPeId: network.outputs.subnetPeId
    uamiId: identity.outputs.uamiId
    storageAccountName: naming.outputs.names.storage
    lawId: diagnostics.outputs.lawId
    tags: tags
  }
}

module gateway 'modules/gateway.bicep' = {
  name: 'gateway'
  scope: deploymentRg
  params: {
    location: location
    agwName: naming.outputs.names.agw
    pipName: naming.outputs.names.pipAgw
    customerIpRanges: customerIpRanges
    publisherIpRanges: publisherIpRanges
    subnetAppgwId: network.outputs.subnetAppgwId
    lawId: diagnostics.outputs.lawId
    tags: tags
  }
}

module ai 'modules/ai.bicep' = {
  name: 'ai'
  scope: deploymentRg
  params: {
    location: location
    aiServicesTier: aiServicesTier
    searchName: naming.outputs.names.search
    aiName: naming.outputs.names.ai
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    tags: tags
  }
}

module automation 'modules/automation.bicep' = {
  name: 'automation'
  scope: deploymentRg
  params: {
    location: location
    automationName: naming.outputs.names.automation
    uamiId: identity.outputs.uamiId
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    tags: tags
  }
}

output names object = naming.outputs.names
