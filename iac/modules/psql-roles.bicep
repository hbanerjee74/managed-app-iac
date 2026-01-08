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

var serverHost = '${psqlName}.postgres.database.azure.com'
// Generate unique script name to avoid conflicts with running scripts
// Use forceUpdateTag in the name to ensure each deployment attempt gets a unique script resource
// This prevents conflicts when a previous script is still running or in a non-terminal state
var forceUpdateTagValue = guid(subscription().id, psqlId, 'psql-create-roles')
var scriptNameSuffix = substring(forceUpdateTagValue, 0, 8)
var scriptName = 'psql-create-roles-${scriptNameSuffix}'

// Load PowerShell script from file
var psqlRolesScript = loadTextContent('../../scripts/create-psql-roles.ps1')

resource createRoles 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
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
