targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('PostgreSQL server resource ID.')
param psqlId string

@description('PostgreSQL server name.')
param psqlName string

@description('Client ID of the UAMI for database login.')
param uamiClientId string

@description('User-assigned managed identity resource ID.')
param uamiId string

@description('Key Vault name for retrieving admin credentials.')
param kvName string

@description('Automation Account resource ID (for runbook creation).')
param automationId string

@description('Automation Account name (for runbook creation).')
param automationName string

@description('Tags to apply.')
param tags object

// PowerShell script is located in scripts/create-psql-roles.ps1
// Runbook content must be uploaded manually after deployment (see instructions below)

// Reference Automation Account
resource automation 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: automationName
}

// PostgreSQL Role Creation Runbook
// This runbook allows admins to create PostgreSQL roles on-demand
// PostgreSQL roles are NOT created automatically during deployment
// Owner must manually upload runbook content, publish, and execute the runbook to create roles
// The runbook accepts parameters: ServerHost, KvName, UamiClientId
// These can be passed when starting the runbook job, or defaults can be configured
// Naming follows RFC-42 convention: kebab-case with {action}-{target} pattern
resource psqlRolesRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automation
  name: 'create-postgresql-roles'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: true
    description: 'Creates PostgreSQL roles (vd_dbo and vd_reader) and grants vd_dbo to UAMI. Can be run by admins for on-demand role creation. Parameters: ServerHost (default: ${psqlName}.postgres.database.azure.com), KvName (default: ${kvName}), UamiClientId (default: ${uamiClientId}).'
  }
  dependsOn: [
    automation
  ]
}

// ============================================================================
// RUNBOOK CONTENT UPLOAD AND EXECUTION
// PostgreSQL roles are NOT created automatically during deployment
// Runbook content must be uploaded and published manually after deployment
// Owner must then manually execute the published runbook to create roles
// Use the following Azure CLI commands:
//
// 1. Upload runbook content:
//   az automation runbook replace-content \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name create-postgresql-roles \
//     --content-path scripts/create-psql-roles.ps1
//
// 2. Publish runbook:
//   az automation runbook publish \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name create-postgresql-roles
//
// 3. Execute runbook (after publishing):
//   az automation runbook start \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name create-postgresql-roles \
//     --parameters SERVER_HOST=<psql-name>.postgres.database.azure.com KV_NAME=<kv-name> UAMI_CLIENT_ID=<uami-client-id>
//
// Runbook is idempotent and can be executed multiple times safely
// ============================================================================
