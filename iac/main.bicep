targetScope = 'resourceGroup'

@description('Resource group name used for deterministic naming (RFC-64: resourceGroupName, same as mrgName). Defaults to current resource group name from ARM context.')
param resourceGroupName string = resourceGroup().name

@description('Azure region for deployment. Defaults to current resource group location from ARM context.')
param location string = resourceGroup().location

@description('Customer admin Entra object ID (RFC-64). Defaults to deployer identity when isManagedApplication is false.')
param customerAdminObjectId string = ''

@description('Contact email for notifications (RFC-64).')
param contactEmail string

@description('Principal type for customerAdminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param customerAdminPrincipalType string = 'User'

@description('VNet address prefix (CIDR notation, e.g., 10.20.0.0/16). Subnets will be automatically derived as /24 subnets.')
param vnetCidr string

@description('Customer IP ranges for WAF allowlist (RFC-64).')
@minLength(1)
param customerIpRanges array

@description('Publisher IP ranges for WAF allowlist (RFC-64).')
@minLength(1)
param publisherIpRanges array

@description('App Service Plan SKU (RFC-64 sku).')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v3'
  'P2v3'
  'P3v3'
])
param sku string = 'B1'

@description('AKS node size (RFC-64 nodeSize). Note: Parameter defined per RFC-64 but currently unused as AKS deployment is out of scope for PRD-30.')
@allowed([
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_D16s_v3'
])
param nodeSize string = 'Standard_D4s_v3'

@description('VM jump host size.')
@allowed([
  'Standard_A1_v2'
  'Standard_A1'
  'Standard_A2_v2'
  'Standard_A4_v2'
  'Standard_B1s'
  'Standard_B2s'
  'Standard_B1ms'
  'Standard_B2ms'
])
param vmSize string = 'Standard_A1_v2'

@description('PostgreSQL compute tier (RFC-64 computeTier).')
@allowed([
  'Standard_B1ms'
  'Standard_B1s'
  'Standard_B2ms'
  'Standard_B2s'
  'GP_Standard_D2s_v3'
  'GP_Standard_D4s_v3'
])
param computeTier string = 'Standard_B1ms'

@description('AI Services tier (RFC-64).')
@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
  'storage_optimized_l1'
  'storage_optimized_l2'
])
param aiServicesTier string = 'basic'

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

@description('VM admin password for jump host.')
@secure()
param vmAdminPassword string = ''

@description('Optional tags: environment (dev/release/prod), owner, purpose, created (ISO8601).')
param environment string = ''
param owner string = ''
param purpose string = ''
param created string = ''

@description('Default tags for non-managed application scenarios (from metadata.defaultTags).')
param defaultTags object = {}

@description('Whether this is a managed application deployment (cross-tenant). Set to false for same-tenant testing.')
param isManagedApplication bool = true

@description('Publisher admin Entra object ID (for managed applications only). Required when isManagedApplication is true.')
param publisherAdminObjectId string = ''

@description('Principal type for publisherAdminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param publisherAdminPrincipalType string = 'User'

// Naming helper to generate deterministic per-resource nanoids.
module naming 'lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
  }
}

// Determine effective customer admin object ID:
// - If isManagedApplication is false and customerAdminObjectId is empty, use deployer identity
// - Otherwise, use provided customerAdminObjectId (required for managed applications)
var deployerInfo = az.deployer()
var effectiveCustomerAdminObjectId = !isManagedApplication && empty(customerAdminObjectId) ? deployerInfo.objectId : customerAdminObjectId

// Use default tags from metadata when isManagedApplication is false and individual tag params are empty
var effectiveTags = !isManagedApplication && empty(environment) && empty(owner) && empty(purpose) && empty(created) ? defaultTags : union(
  empty(environment) ? {} : { environment: environment },
  empty(owner) ? {} : { owner: owner },
  empty(purpose) ? {} : { purpose: purpose },
  empty(created) ? {} : { created: created },
  empty(contactEmail) ? {} : { contactEmail: contactEmail }
)

var tags = effectiveTags

// TODO: add remaining RFC-64 parameters as modules are implemented.

module diagnostics 'modules/diagnostics.bicep' = {
  name: 'diagnostics'
  dependsOn: [
    naming
  ]
  params: {
    location: location
    retentionDays: retentionDays
    lawName: naming.outputs.names.law
    tags: tags
  }
}

module identity 'modules/identity.bicep' = {
  name: 'identity'
  dependsOn: [
    naming
    diagnostics
  ]
  params: {
    location: location
    uamiName: naming.outputs.names.uami
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  dependsOn: [
    naming
  ]
  params: {
    location: location
    vnetName: naming.outputs.names.vnet
    vnetCidr: vnetCidr
    nsgAppgwName: naming.outputs.names.nsgAppgw
    nsgAksName: naming.outputs.names.nsgAks
    nsgAppsvcName: naming.outputs.names.nsgAppsvc
    nsgPeName: naming.outputs.names.nsgPe
    tags: tags
  }
}

module dns 'modules/dns.bicep' = {
  name: 'dns'
  dependsOn: [
    naming
    network
  ]
  params: {
    vnetName: naming.outputs.names.vnet
    tags: tags
  }
}

module kv 'modules/kv.bicep' = {
  name: 'kv'
  dependsOn: [
    naming
    network
    diagnostics
    dns
  ]
  params: {
    location: location
    kvName: naming.outputs.names.kv
    subnetPeId: network.outputs.subnetPeId
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
  dependsOn: [
    naming
    network
    diagnostics
    dns
  ]
  params: {
    location: location
    storageName: naming.outputs.names.storage
    subnetPeId: network.outputs.subnetPeId
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

module acr 'modules/acr.bicep' = {
  name: 'acr'
  dependsOn: [
    naming
    network
    diagnostics
    dns
  ]
  params: {
    location: location
    acrName: naming.outputs.names.acr
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peAcrName: naming.outputs.names.peAcr
    peAcrDnsName: naming.outputs.names.peAcrDns
    diagAcrName: naming.outputs.names.diagAcr
    tags: tags
  }
}

module psql 'modules/psql.bicep' = {
  name: 'psql'
  dependsOn: [
    naming
    network
    diagnostics
    dns
    kv
  ]
  params: {
    location: location
    psqlName: naming.outputs.names.psql
    computeTier: computeTier
    backupRetentionDays: backupRetentionDays
    storageGB: storageGB
    subnetPsqlId: network.outputs.subnetPsqlId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    diagPsqlName: naming.outputs.names.diagPsql
    kvName: naming.outputs.names.kv
    tags: tags
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  dependsOn: [
    naming
  ]
  params: {
    location: location
    sku: sku
    aspName: naming.outputs.names.asp
    tags: tags
  }
}

module publicIp 'modules/public-ip.bicep' = {
  name: 'publicIp'
  dependsOn: [
    naming
  ]
  params: {
    location: location
    pipName: naming.outputs.names.pipAgw
    tags: tags
  }
}

var wafPolicyName = '${naming.outputs.names.agw}-waf'

module wafPolicy 'modules/waf-policy.bicep' = {
  name: 'wafPolicy'
  dependsOn: [
    naming
  ]
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
  dependsOn: [
    naming
    publicIp
    wafPolicy
    network
    diagnostics
  ]
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
  dependsOn: [
    naming
    network
    diagnostics
    dns
  ]
  params: {
    location: location
    aiServicesTier: aiServicesTier
    searchName: naming.outputs.names.search
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peSearchName: naming.outputs.names.peSearch
    peSearchDnsName: naming.outputs.names.peSearchDns
    diagSearchName: naming.outputs.names.diagSearch
    tags: tags
  }
}

module cognitiveServices 'modules/cognitive-services.bicep' = {
  name: 'cognitive-services'
  dependsOn: [
    naming
    network
    diagnostics
    dns
  ]
  params: {
    location: location
    aiName: naming.outputs.names.ai
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peAiName: naming.outputs.names.peAi
    peAiDnsName: naming.outputs.names.peAiDns
    diagAiName: naming.outputs.names.diagAi
    tags: tags
  }
}

module automation 'modules/automation.bicep' = {
  name: 'automation'
  dependsOn: [
    naming
    diagnostics
  ]
  params: {
    location: location
    automationName: naming.outputs.names.automation
    lawId: diagnostics.outputs.lawId
    diagAutomationName: naming.outputs.names.diagAutomation
    tags: tags
  }
}

module psqlRoles 'modules/psql-roles.bicep' = {
  name: 'psql-roles'
  dependsOn: [
    psql
    identity
    automation
    kv
  ]
  params: {
    location: location
    psqlId: psql.outputs.psqlId
    psqlName: psql.outputs.psqlName
    uamiClientId: identity.outputs.uamiClientId
    uamiId: identity.outputs.uamiId
    kvName: naming.outputs.names.kv
    automationId: automation.outputs.automationId
    automationName: automation.outputs.automationName
    tags: tags
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'bastion'
  dependsOn: [
    naming
    network
  ]
  params: {
    location: location
    bastionName: naming.outputs.names.bastion
    pipBastionName: naming.outputs.names.pipBastion
    subnetBastionId: network.outputs.subnetBastionId
    tags: tags
  }
}

module vmJumphost 'modules/vm-jumphost.bicep' = {
  name: 'vm-jumphost'
  dependsOn: [
    naming
    network
    kv
  ]
  params: {
    location: location
    vmName: naming.outputs.names.vm
    subnetId: network.outputs.subnetPeId
    kvName: naming.outputs.names.kv
    adminPassword: vmAdminPassword
    vmSize: vmSize
    tags: tags
  }
}

// Grant Automation Job Operator role to deployer identity (non-managed app only)
// This allows the identity running the deployment script to execute automation runbooks
var deployerObjectId = deployerInfo.objectId
// Determine principal type: if userPrincipalName is empty, it's likely a ServicePrincipal
var deployerPrincipalType = empty(deployerInfo.userPrincipalName) ? 'ServicePrincipal' : 'User'

resource automationAccountForRbac 'Microsoft.Automation/automationAccounts@2023-11-01' existing = if (!isManagedApplication) {
  name: automation.outputs.automationName
}

resource deployerAutomationJobOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!isManagedApplication) {
  name: guid(automationAccountForRbac.id, deployerObjectId, 'automation-job-operator')
  scope: automationAccountForRbac
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4fe576fe-1146-4730-92eb-48519fa6bf9f') // Automation Job Operator
    principalId: deployerObjectId
    principalType: deployerPrincipalType
  }
  dependsOn: [
    automation
    automationAccountForRbac
  ]
}

module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  dependsOn: [
    naming
    identity
    diagnostics
    kv
    storage
    acr
    search
    cognitiveServices
    automation
  ]
  params: {
    location: location
    uamiPrincipalId: identity.outputs.uamiPrincipalId
    uamiId: identity.outputs.uamiId
    customerAdminObjectId: effectiveCustomerAdminObjectId
    customerAdminPrincipalType: customerAdminPrincipalType
    lawId: diagnostics.outputs.lawId
    lawName: naming.outputs.names.law
    kvId: kv.outputs.kvId
    storageId: storage.outputs.storageId
    acrId: acr.outputs.acrId
    searchId: search.outputs.searchId
    aiId: cognitiveServices.outputs.aiId
    automationId: automation.outputs.automationId
    automationName: automation.outputs.automationName
    isManagedApplication: isManagedApplication
    publisherAdminObjectId: publisherAdminObjectId
    publisherAdminPrincipalType: publisherAdminPrincipalType
    tags: tags
  }
}

output names object = naming.outputs.names
output lawId string = diagnostics.outputs.lawId
output lawWorkspaceId string = diagnostics.outputs.lawWorkspaceId
output vmName string = vmJumphost.outputs.vmName
output vmPrivateIp string = vmJumphost.outputs.vmPrivateIp
output bastionName string = bastion.outputs.bastionName
