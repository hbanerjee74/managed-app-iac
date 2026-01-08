targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('PostgreSQL compute tier SKU.')
param computeTier string

@description('PostgreSQL server name.')
param psqlName string

@description('Delegated subnet ID for PostgreSQL Flexible Server.')
param subnetPsqlId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('PostgreSQL storage size (GB).')
param storageGB int = 128

@description('PostgreSQL backup retention days.')
param backupRetentionDays int = 7

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object

@description('Diagnostic setting name from naming helper.')
param diagPsqlName string

@description('Key Vault name for storing admin credentials.')
param kvName string

@description('PostgreSQL admin username (optional, defaults to psqladmin).')
param psqlAdminUsername string = 'psqladmin'

@description('PostgreSQL admin password (optional, auto-generated if not provided).')
@secure()
param psqlAdminPassword string = ''

@description('Optional tags to apply.')
param tags object = {}

// Reference Key Vault resource
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kvName
}

// Generate secure password if not provided
var psqlAdminPasswordValue = empty(psqlAdminPassword) ? guid(subscription().id, kv.id, 'psql-admin-password') : psqlAdminPassword

// Create PostgreSQL admin username secret in Key Vault
resource psqlAdminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'psql-admin-username'
  properties: {
    value: psqlAdminUsername
  }
}

// Create PostgreSQL admin password secret in Key Vault
resource psqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'psql-admin-password'
  properties: {
    value: psqlAdminPasswordValue
  }
}

resource psql 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: psqlName
  location: location
  tags: tags
  sku: {
    name: computeTier
    tier: startsWith(computeTier, 'Standard_B') ? 'Burstable' : 'GeneralPurpose'
  }
  properties: {
    administratorLogin: psqlAdminUsername
    administratorLoginPassword: psqlAdminPasswordValue
    version: '16'
    storage: {
      storageSizeGB: storageGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: subnetPsqlId
      privateDnsZoneArmResourceId: zoneIds.postgres
      publicNetworkAccess: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
    highAvailability: {
      mode: 'Disabled'
    }
    createMode: 'Default'
  }
}

output psqlId string = psql.id
output psqlName string = psql.name

resource psqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagPsqlName
  scope: psql
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'PostgreSQLLogs'
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
