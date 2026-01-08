targetScope = 'resourceGroup'

// Test wrapper for psql module (PostgreSQL)
// This module depends on: network, diagnostics, dns

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('VNet address prefix (CIDR notation, e.g., 10.20.0.0/16).')
param vnetCidr string

@description('PostgreSQL compute tier (RFC-64: computeTier).')
param computeTier string

@description('PostgreSQL storage in GB (RFC-64: storageGB).')
param storageGB int

@description('PostgreSQL backup retention days (RFC-64: backupRetentionDays).')
param backupRetentionDays int

@description('Log Analytics retention in days (RFC-64: retentionDays).')
param retentionDays int

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
  }
}

// Dependency modules - use actual modules instead of mocks
module network '../../../iac/modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: naming.outputs.names.vnet
    vnetCidr: vnetCidr
    nsgAppgwName: naming.outputs.names.nsgAppgw
    nsgAksName: naming.outputs.names.nsgAks
    nsgAppsvcName: naming.outputs.names.nsgAppsvc
    nsgPeName: naming.outputs.names.nsgPe
    tags: {}
  }
}

module diagnostics '../../../iac/modules/diagnostics.bicep' = {
  name: 'diagnostics'
  params: {
    location: location
    retentionDays: retentionDays
    lawName: naming.outputs.names.law
    tags: {}
  }
}

module dns '../../../iac/modules/dns.bicep' = {
  name: 'dns'
  params: {
    vnetName: naming.outputs.names.vnet
    tags: {}
  }
}

module identity '../../../iac/modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
    uamiName: naming.outputs.names.uami
    tags: {}
  }
}

module kv '../../../iac/modules/kv.bicep' = {
  name: 'kv'
  params: {
    location: location
    kvName: naming.outputs.names.kv
    subnetPeId: network.outputs.subnetPeId
    lawId: diagnostics.outputs.lawId
    zoneIds: dns.outputs.zoneIds
    peKvName: naming.outputs.names.peKv
    peKvDnsName: naming.outputs.names.peKvDns
    diagKvName: naming.outputs.names.diagKv
    tags: {}
  }
}

// Module under test
module psql '../../../iac/modules/psql.bicep' = {
  name: 'psql'
  dependsOn: [
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
    tags: {}
  }
}

output psqlId string = psql.outputs.psqlId
output psqlName string = psql.outputs.psqlName
output names object = naming.outputs.names

