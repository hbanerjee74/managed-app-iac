targetScope = 'resourceGroup'

// Test wrapper for data module (PostgreSQL)
// This module depends on: network, identity, diagnostics, dns

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

@description('PostgreSQL compute tier (RFC-64: computeTier).')
param computeTier string

@description('PostgreSQL storage in GB (RFC-64: storageGB).')
param storageGB int

@description('PostgreSQL backup retention days (RFC-64: backupRetentionDays).')
param backupRetentionDays int

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  scope: subscription()
  params: {
    resourceGroupName: resourceGroupName
    purpose: 'platform'
  }
}

// Mock dependency outputs
var mockNetworkOutputs = {
  subnetPsqlId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-psql'
}

var mockIdentityOutputs = {
  uamiPrincipalId: '00000000-0000-0000-0000-000000000000'
  uamiClientId: '00000000-0000-0000-0000-000000000000'
  uamiId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-uami'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

var mockDnsOutputs = {
  zoneIds: {
    postgres: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com'
  }
}

// Module under test
module data '../../../iac/modules/data.bicep' = {
  name: 'data'
  params: {
    location: location
    psqlName: naming.outputs.names.psql
    computeTier: computeTier
    backupRetentionDays: backupRetentionDays
    storageGB: storageGB
    subnetPsqlId: mockNetworkOutputs.subnetPsqlId
    uamiPrincipalId: mockIdentityOutputs.uamiPrincipalId
    lawId: mockDiagnosticsOutputs.lawId
    uamiClientId: mockIdentityOutputs.uamiClientId
    uamiId: mockIdentityOutputs.uamiId
    zoneIds: mockDnsOutputs.zoneIds
    diagPsqlName: naming.outputs.names.diagPsql
    tags: {}
  }
}

output psqlId string = data.outputs.psqlId
output names object = naming.outputs.names

