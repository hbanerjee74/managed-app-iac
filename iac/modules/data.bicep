targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('PostgreSQL compute tier SKU.')
param postgresComputeTier string

@description('PostgreSQL server name.')
param psqlName string

@description('Delegated subnet ID for PostgreSQL Flexible Server.')
param subnetPsqlId string

@description('Principal ID of the UAMI for RBAC.')
param uamiPrincipalId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('Client ID of the UAMI for database login.')
param uamiClientId string

@description('User-assigned managed identity resource ID.')
param uamiId string

@description('Optional tags to apply.')
param tags object = {}

#disable-next-line no-hardcoded-env-urls
var ossrdbmsResource = 'https://ossrdbms-aad.database.windows.net'

resource psql 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: psqlName
  location: location
  tags: tags
  sku: {
    name: postgresComputeTier
    tier: 'GeneralPurpose'
  }
  properties: {
    administratorLogin: null
    administratorLoginPassword: null
    version: '16'
    storage: {
      storageSizeGB: 128
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: subnetPsqlId
      privateDnsZoneArmResourceId: resourceId(resourceGroup().name, 'Microsoft.Network/privateDnsZones', 'privatelink.postgres.database.azure.com')
      publicNetworkAccess: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: subscription().tenantId
    }
    highAvailability: {
      mode: 'Disabled'
    }
    createMode: 'Default'
  }
}

var serverHost = '${psqlName}.postgres.database.azure.com'

resource createRoles 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'psql-create-roles'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: guid(subscription().id, psql.id, 'psql-create-roles')
    retentionInterval: 'PT1H'
    azCliVersion: '2.61.0'
    //disable-next-line no-hardcoded-env-urls
    scriptContent: '''
#!/usr/bin/env bash
set -euo pipefail
SERVER="${SERVER_HOST}"
LOGIN_USER="${UAMI_CLIENT_ID}"

echo "Acquiring AAD token for Postgres..."
ACCESS_TOKEN=$(az account get-access-token --resource ${RESOURCE_URI} --query accessToken -o tsv)
export PGPASSWORD="$ACCESS_TOKEN"

echo "Creating roles vd_dbo and vd_reader if missing, and granting vd_dbo to UAMI..."
psql "host=${SERVER} user=${LOGIN_USER} dbname=postgres sslmode=require" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'vd_dbo') THEN
    CREATE ROLE "vd_dbo";
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'vd_reader') THEN
    CREATE ROLE "vd_reader";
  END IF;
END$$;
GRANT "vd_dbo" TO "${LOGIN_USER}";
SQL
'''
    supportingScriptUris: []
    timeout: 'PT10M'
    environmentVariables: [
      {
        name: 'SERVER_HOST'
        //disable-next-line no-hardcoded-env-urls
        value: serverHost
      }
      {
        name: 'UAMI_CLIENT_ID'
        value: uamiClientId
      }
      {
        name: 'RESOURCE_URI'
        value: ossrdbmsResource
      }
    ]
  }
}

resource psqlAdminRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(psql.id, uamiPrincipalId, 'psql-admin')
  scope: psql
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1f21df41-19d2-41e1-8a5e-3cbb7a0c2bd2') // PostgreSQL Flexible Server Administrator
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output psqlId string = psql.id

resource psqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-law-psql'
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

// TODO: deploy PostgreSQL Flexible Server v16 with roles per PRD-30.
