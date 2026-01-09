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

var serverHost = '${psqlName}.postgres.database.azure.com'
// Generate unique script name to avoid conflicts with running scripts
// Use forceUpdateTag in the name to ensure each deployment attempt gets a unique script resource
// This prevents conflicts when a previous script is still running or in a non-terminal state
var forceUpdateTagValue = guid(subscription().id, psqlId, 'psql-create-roles')
var scriptNameSuffix = substring(forceUpdateTagValue, 0, 8)
var scriptName = 'psql-create-roles-${scriptNameSuffix}'

// Load PowerShell script from file (used by deployment script for initial role creation)
var psqlRolesScript = loadTextContent('../../scripts/create-psql-roles.ps1')

// Reference Automation Account
resource automation 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: automationName
}

// Deployment script for initial role creation during deployment
resource createPgRoles 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: scriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: forceUpdateTagValue
    retentionInterval: 'PT1H'
    azPowerShellVersion: '11.0'
    scriptContent: psqlRolesScript
    supportingScriptUris: []
    timeout: 'PT10M'
    environmentVariables: [
      {
        name: 'SERVER_HOST'
        //disable-next-line no-hardcoded-env-urls
        value: serverHost
      }
      {
        name: 'KV_NAME'
        value: kvName
      }
      {
        name: 'UAMI_CLIENT_ID'
        value: uamiClientId
      }
    ]
  }
}

// PostgreSQL Role Creation Runbook
// This runbook allows admins to create PostgreSQL roles on-demand
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
// RUNBOOK CONTENT UPLOAD
// Runbook content must be uploaded and published manually after deployment
// Use the following Azure CLI commands:
//
// For create-postgresql-roles:
//   az automation runbook replace-content \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name create-postgresql-roles \
//     --content-path scripts/create-psql-roles.ps1
//   az automation runbook publish \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name create-postgresql-roles
//
// Note: The deployment script (createPgRoles) above creates roles during deployment.
// The runbook is for on-demand role creation/re-application after deployment.
// ============================================================================
