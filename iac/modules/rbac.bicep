targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('User-assigned managed identity principal ID.')
param uamiPrincipalId string

@description('User-assigned managed identity resource ID.')
param uamiId string

@description('Customer admin Entra object ID.')
param customerAdminObjectId string

@description('Principal type for customerAdminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param customerAdminPrincipalType string = 'User'

@description('Log Analytics Workspace resource ID.')
param lawId string = ''

@description('Log Analytics Workspace name.')
param lawName string = ''

@description('Key Vault resource ID.')
param kvId string

@description('Storage Account resource ID.')
param storageId string

@description('Container Registry resource ID.')
param acrId string

@description('Azure AI Search resource ID.')
param searchId string

@description('Cognitive Services resource ID.')
param aiId string

@description('Automation Account resource ID.')
param automationId string

@description('Automation Account name (for runbook creation).')
param automationName string = ''

@description('Whether this is a managed application deployment (cross-tenant). Set to false for same-tenant testing.')
param isManagedApplication bool = true

@description('Publisher admin Entra object ID (for managed applications only).')
param publisherAdminObjectId string = ''

@description('Principal type for publisherAdminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param publisherAdminPrincipalType string = 'User'

@description('Optional tags to apply.')
param tags object = {}

// Load PowerShell scripts from files
var rbacUamiScript = loadTextContent('../../scripts/assign-rbac-roles-uami.ps1')
var rbacCustomerAdminScript = loadTextContent('../../scripts/assign-rbac-roles-admin.ps1')
var rbacPublisherAdminScript = loadTextContent('../../scripts/assign-rbac-roles-publisher-admin.ps1')

// Reference Automation Account (if provided)
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' existing = if (!empty(automationId) && !empty(automationName)) {
  name: automationName
}

// Generate unique script names for deploymentScripts
var uamiForceUpdateTagValue = guid(resourceGroup().id, uamiId, 'rbac-uami-assignments')
var uamiScriptNameSuffix = substring(uamiForceUpdateTagValue, 0, 8)
var uamiScriptName = 'assign-rbac-roles-uami-${uamiScriptNameSuffix}'

var customerAdminForceUpdateTagValue = guid(resourceGroup().id, customerAdminObjectId, 'rbac-customer-admin-assignments')
var customerAdminScriptNameSuffix = substring(customerAdminForceUpdateTagValue, 0, 8)
var customerAdminScriptName = 'assign-rbac-roles-customer-admin-${customerAdminScriptNameSuffix}'

var publisherAdminForceUpdateTagValue = guid(resourceGroup().id, publisherAdminObjectId, 'rbac-publisher-admin-assignments')
var publisherAdminScriptNameSuffix = substring(publisherAdminForceUpdateTagValue, 0, 8)
var publisherAdminScriptName = 'assign-rbac-roles-publisher-admin-${publisherAdminScriptNameSuffix}'

// Deployment script for UAMI RBAC role assignments during deployment
resource assignRbacRolesUami 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: uamiScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: uamiForceUpdateTagValue
    retentionInterval: 'PT1H'
    azPowerShellVersion: '11.0'
    scriptContent: rbacUamiScript
    supportingScriptUris: []
    timeout: 'PT15M'
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP_ID'
        value: resourceGroup().id
      }
      {
        name: 'UAMI_PRINCIPAL_ID'
        value: uamiPrincipalId
      }
      {
        name: 'UAMI_ID'
        value: uamiId
      }
      {
        name: 'LAW_ID'
        value: lawId
      }
      {
        name: 'LAW_NAME'
        value: lawName
      }
      {
        name: 'KV_ID'
        value: kvId
      }
      {
        name: 'STORAGE_ID'
        value: storageId
      }
      {
        name: 'ACR_ID'
        value: acrId
      }
      {
        name: 'SEARCH_ID'
        value: searchId
      }
      {
        name: 'AI_ID'
        value: aiId
      }
      {
        name: 'AUTOMATION_ID'
        value: automationId
      }
      {
        name: 'IS_MANAGED_APPLICATION'
        value: string(isManagedApplication)
      }
    ]
  }
}

// Deployment script for Customer Admin RBAC role assignments during deployment
resource assignRbacRolesCustomerAdmin 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (!empty(customerAdminObjectId)) {
  name: customerAdminScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: customerAdminForceUpdateTagValue
    retentionInterval: 'PT1H'
    azPowerShellVersion: '11.0'
    scriptContent: rbacCustomerAdminScript
    supportingScriptUris: []
    timeout: 'PT15M'
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP_ID'
        value: resourceGroup().id
      }
      {
        name: 'CUSTOMER_ADMIN_OBJECT_ID'
        value: customerAdminObjectId
      }
      {
        name: 'CUSTOMER_ADMIN_PRINCIPAL_TYPE'
        value: customerAdminPrincipalType
      }
      {
        name: 'KV_ID'
        value: kvId
      }
      {
        name: 'STORAGE_ID'
        value: storageId
      }
      {
        name: 'ACR_ID'
        value: acrId
      }
      {
        name: 'SEARCH_ID'
        value: searchId
      }
      {
        name: 'AI_ID'
        value: aiId
      }
      {
        name: 'AUTOMATION_ID'
        value: automationId
      }
    ]
  }
}

// Deployment script for Publisher Admin RBAC role assignments during deployment
// Only runs for managed applications when publisherAdminObjectId is provided
resource assignRbacRolesPublisherAdmin 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (isManagedApplication && !empty(publisherAdminObjectId)) {
  name: publisherAdminScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: publisherAdminForceUpdateTagValue
    retentionInterval: 'PT1H'
    azPowerShellVersion: '11.0'
    scriptContent: rbacPublisherAdminScript
    supportingScriptUris: []
    timeout: 'PT15M'
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP_ID'
        value: resourceGroup().id
      }
      {
        name: 'PUBLISHER_ADMIN_OBJECT_ID'
        value: publisherAdminObjectId
      }
      {
        name: 'PUBLISHER_ADMIN_PRINCIPAL_TYPE'
        value: publisherAdminPrincipalType
      }
      {
        name: 'KV_ID'
        value: kvId
      }
      {
        name: 'STORAGE_ID'
        value: storageId
      }
      {
        name: 'ACR_ID'
        value: acrId
      }
      {
        name: 'SEARCH_ID'
        value: searchId
      }
      {
        name: 'AI_ID'
        value: aiId
      }
      {
        name: 'AUTOMATION_ID'
        value: automationId
      }
    ]
  }
}

// ============================================================================
// RBAC ASSIGNMENTS MOVED TO POWERSHELL SCRIPTS
// All role assignments are now performed by separate scripts:
// - assign-rbac-roles-uami.ps1 for UAMI role assignments
// - assign-rbac-roles-admin.ps1 for Customer Admin role assignments
// Scripts are executed via deploymentScripts above and available as automation runbooks below
// ============================================================================

// Automation Runbook for UAMI RBAC role assignments
// This runbook allows admins to re-apply UAMI RBAC assignments on-demand
// Naming follows RFC-42 convention: kebab-case with {action}-{target} pattern
resource rbacUamiRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (!empty(automationId) && !empty(automationName)) {
  parent: automationAccount
  name: 'assign-rbac-roles-uami'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: true
    description: 'Assigns all RBAC roles for UAMI. Can be run by admins to re-apply UAMI RBAC assignments. Parameters: ResourceGroupId, UamiPrincipalId, UamiId, LawId, LawName, KvId, StorageId, AcrId, SearchId, AiId, AutomationId, IsManagedApplication.'
  }
  dependsOn: [
    automationAccount
  ]
}

// UAMI Runbook draft - required parent for content
resource rbacUamiRunbookDraft 'Microsoft.Automation/automationAccounts/runbooks/draft@2019-06-01' = if (!empty(automationId) && !empty(automationName)) {
  parent: rbacUamiRunbook
  name: 'content'
}

// UAMI Runbook draft content (PowerShell script)
// Runbook is automatically published by publishRbacRunbooks deployment script
resource rbacUamiRunbookContent 'Microsoft.Automation/automationAccounts/runbooks/draft/content@2019-06-01' = if (!empty(automationId) && !empty(automationName)) {
  parent: rbacUamiRunbookDraft
  name: 'content'
  properties: {
    content: rbacUamiScript
  }
}

// Automation Runbook for Customer Admin RBAC role assignments
// This runbook allows admins to re-apply Customer Admin RBAC assignments on-demand
// Naming follows RFC-42 convention: kebab-case with {action}-{target} pattern
resource rbacCustomerAdminRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (!empty(automationId) && !empty(automationName) && !empty(customerAdminObjectId)) {
  parent: automationAccount
  name: 'assign-rbac-roles-admin'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: true
    description: 'Assigns all RBAC roles for Customer Admin. Can be run by admins to re-apply Customer Admin RBAC assignments. Parameters: ResourceGroupId, CustomerAdminObjectId, CustomerAdminPrincipalType (User or Group, defaults to User), KvId, StorageId, AcrId, SearchId, AiId, AutomationId.'
  }
  dependsOn: [
    automationAccount
  ]
}

// Customer Admin Runbook draft - required parent for content
resource rbacCustomerAdminRunbookDraft 'Microsoft.Automation/automationAccounts/runbooks/draft@2019-06-01' = if (!empty(automationId) && !empty(automationName) && !empty(customerAdminObjectId)) {
  parent: rbacCustomerAdminRunbook
  name: 'content'
}

// Customer Admin Runbook draft content (PowerShell script)
// Runbook is automatically published by publishRbacRunbooks deployment script
resource rbacCustomerAdminRunbookContent 'Microsoft.Automation/automationAccounts/runbooks/draft/content@2019-06-01' = if (!empty(automationId) && !empty(automationName) && !empty(customerAdminObjectId)) {
  parent: rbacCustomerAdminRunbookDraft
  name: 'content'
  properties: {
    content: rbacCustomerAdminScript
  }
}

// Automation Runbook for Publisher Admin RBAC role assignments
// This runbook allows admins to re-apply Publisher Admin RBAC assignments on-demand
// Only created for managed applications
// Naming follows RFC-42 convention: kebab-case with {action}-{target} pattern
resource rbacPublisherAdminRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (isManagedApplication && !empty(automationId) && !empty(automationName) && !empty(publisherAdminObjectId)) {
  parent: automationAccount
  name: 'assign-rbac-roles-publisher-admin'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: true
    description: 'Assigns all RBAC roles for Publisher Admin (same as Customer Admin). Can be run by admins to re-apply Publisher Admin RBAC assignments. Parameters: ResourceGroupId, PublisherAdminObjectId, PublisherAdminPrincipalType, KvId, StorageId, AcrId, SearchId, AiId, AutomationId.'
  }
  dependsOn: [
    automationAccount
  ]
}

// Publisher Admin Runbook draft - required parent for content
resource rbacPublisherAdminRunbookDraft 'Microsoft.Automation/automationAccounts/runbooks/draft@2019-06-01' = if (isManagedApplication && !empty(automationId) && !empty(automationName) && !empty(publisherAdminObjectId)) {
  parent: rbacPublisherAdminRunbook
  name: 'content'
}

// Publisher Admin Runbook draft content (PowerShell script)
// Runbook is automatically published by publishRbacRunbooks deployment script
resource rbacPublisherAdminRunbookContent 'Microsoft.Automation/automationAccounts/runbooks/draft/content@2019-06-01' = if (isManagedApplication && !empty(automationId) && !empty(automationName) && !empty(publisherAdminObjectId)) {
  parent: rbacPublisherAdminRunbookDraft
  name: 'content'
  properties: {
    content: rbacPublisherAdminScript
  }
}

// ============================================================================
// AUTO-PUBLISH RUNBOOKS
// Deployment script to automatically publish all runbooks after they're created
// This ensures runbooks are immediately available for execution without manual publishing
// ============================================================================

var publishRunbooksForceUpdateTagValue = guid(resourceGroup().id, automationId, 'publish-rbac-runbooks')
var publishRunbooksScriptNameSuffix = substring(publishRunbooksForceUpdateTagValue, 0, 8)
var publishRunbooksScriptName = 'publish-rbac-runbooks-${publishRunbooksScriptNameSuffix}'

// Deployment script to publish all RBAC runbooks automatically
resource publishRbacRunbooks 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (!empty(automationId) && !empty(automationName)) {
  name: publishRunbooksScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: publishRunbooksForceUpdateTagValue
    retentionInterval: 'PT1H'
    azPowerShellVersion: '11.0'
    scriptContent: '''
      $ErrorActionPreference = "Stop"
      
      $AutomationAccountName = "${automationName}"
      $ResourceGroupName = "${resourceGroup().name}"
      $HasCustomerAdmin = "$env:HAS_CUSTOMER_ADMIN"
      $IsManagedApp = "$env:IS_MANAGED_APPLICATION"
      $HasPublisherAdmin = "$env:HAS_PUBLISHER_ADMIN"
      
      Write-Host "Publishing RBAC runbooks..." -ForegroundColor Cyan
      
      # Publish UAMI runbook (always created if automation account exists)
      Write-Host "Publishing assign-rbac-roles-uami runbook..." -ForegroundColor Yellow
      try {
        az automation runbook publish `
          --automation-account-name $AutomationAccountName `
          --resource-group $ResourceGroupName `
          --name assign-rbac-roles-uami `
          --output none 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
          Write-Host "Successfully published assign-rbac-roles-uami" -ForegroundColor Green
        } else {
          Write-Warning "Failed to publish assign-rbac-roles-uami (exit code: $LASTEXITCODE)"
        }
      } catch {
        Write-Warning "Failed to publish assign-rbac-roles-uami: $_"
      }
      
      # Publish Customer Admin runbook (if customerAdminObjectId is provided)
      if ($HasCustomerAdmin -eq "True") {
        Write-Host "Publishing assign-rbac-roles-admin runbook..." -ForegroundColor Yellow
        try {
          az automation runbook publish `
            --automation-account-name $AutomationAccountName `
            --resource-group $ResourceGroupName `
            --name assign-rbac-roles-admin `
            --output none 2>&1 | Out-Null
          if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully published assign-rbac-roles-admin" -ForegroundColor Green
          } else {
            Write-Warning "Failed to publish assign-rbac-roles-admin (exit code: $LASTEXITCODE)"
          }
        } catch {
          Write-Warning "Failed to publish assign-rbac-roles-admin: $_"
        }
      } else {
        Write-Host "Skipping assign-rbac-roles-admin (customerAdminObjectId not provided)" -ForegroundColor Gray
      }
      
      # Publish Publisher Admin runbook (if managed application and publisherAdminObjectId is provided)
      if ($IsManagedApp -eq "True" -and $HasPublisherAdmin -eq "True") {
        Write-Host "Publishing assign-rbac-roles-publisher-admin runbook..." -ForegroundColor Yellow
        try {
          az automation runbook publish `
            --automation-account-name $AutomationAccountName `
            --resource-group $ResourceGroupName `
            --name assign-rbac-roles-publisher-admin `
            --output none 2>&1 | Out-Null
          if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully published assign-rbac-roles-publisher-admin" -ForegroundColor Green
          } else {
            Write-Warning "Failed to publish assign-rbac-roles-publisher-admin (exit code: $LASTEXITCODE)"
          }
        } catch {
          Write-Warning "Failed to publish assign-rbac-roles-publisher-admin: $_"
        }
      } else {
        Write-Host "Skipping assign-rbac-roles-publisher-admin (not a managed application or publisherAdminObjectId not provided)" -ForegroundColor Gray
      }
      
      Write-Host "Runbook publishing completed" -ForegroundColor Cyan
    '''
    supportingScriptUris: []
    timeout: 'PT10M'
    environmentVariables: [
      {
        name: 'HAS_CUSTOMER_ADMIN'
        value: string(!empty(customerAdminObjectId))
      }
      {
        name: 'IS_MANAGED_APPLICATION'
        value: string(isManagedApplication)
      }
      {
        name: 'HAS_PUBLISHER_ADMIN'
        value: string(!empty(publisherAdminObjectId))
      }
    ]
  }
  dependsOn: [
    rbacUamiRunbookContent
    rbacCustomerAdminRunbookContent
    rbacPublisherAdminRunbookContent
  ]
}

// ============================================================================
// LEGACY RBAC ASSIGNMENTS REMOVED
// All RBAC assignments are now handled by the PowerShell script executed via deploymentScripts
// The script creates all role assignments programmatically using Azure CLI
// Legacy Bicep resources have been replaced with script execution for better maintainability
// ============================================================================
