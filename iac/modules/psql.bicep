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
param storageGB int

@description('PostgreSQL backup retention days.')
param backupRetentionDays int

@description('DNS zone resource IDs map (from dns module).')
param zoneIds object

@description('Diagnostic setting name from naming helper.')
param diagPsqlName string

@description('Key Vault name for storing admin credentials.')
param kvName string

@description('PostgreSQL admin username.')
param psqlAdminUsername string

@description('PostgreSQL admin password.')
@secure()
param psqlAdminPassword string

@description('PostgreSQL admin username secret name in Key Vault.')
param psqlAdminUsernameSecretName string

@description('PostgreSQL admin password secret name in Key Vault.')
param psqlAdminPasswordSecretName string

@description('Tags to apply.')
param tags object

// Reference Key Vault resource
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kvName
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
    administratorLoginPassword: psqlAdminPassword
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
