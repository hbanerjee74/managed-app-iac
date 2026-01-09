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
param customerAdminPrincipalType string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('Log Analytics Workspace name.')
param lawName string

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
param automationName string

@description('Whether this is a managed application deployment (cross-tenant). Set to false for same-tenant testing.')
param isManagedApplication bool

@description('Publisher admin Entra object ID (for managed applications only).')
param publisherAdminObjectId string

@description('Principal type for publisherAdminObjectId (User or Group).')
@allowed([
  'User'
  'Group'
])
param publisherAdminPrincipalType string

@description('Tags to apply.')
param tags object

// Load PowerShell scripts from files
var rbacUamiScript = loadTextContent('../../scripts/assign-rbac-roles-uami.ps1')
var rbacCustomerAdminScript = loadTextContent('../../scripts/assign-rbac-roles-admin.ps1')
var rbacPublisherAdminScript = loadTextContent('../../scripts/assign-rbac-roles-publisher-admin.ps1')

// Reference Automation Account
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: automationName
}

// ============================================================================
// RBAC ASSIGNMENTS VIA AUTOMATION RUNBOOKS
// All role assignments are performed by PowerShell scripts available as automation runbooks
// Runbooks are created and published during deployment, but must be manually executed by the owner
// - assign-rbac-roles-uami.ps1 for UAMI role assignments
// - assign-rbac-roles-admin.ps1 for Customer Admin role assignments
// - assign-rbac-roles-publisher-admin.ps1 for Publisher Admin role assignments
// ============================================================================

// Automation Runbook for UAMI RBAC role assignments
// This runbook allows admins to re-apply UAMI RBAC assignments on-demand
// Naming follows RFC-42 convention: kebab-case with {action}-{target} pattern
resource rbacUamiRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
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

// UAMI Runbook draft content will be uploaded via deployment script below

// Automation Runbook for Customer Admin RBAC role assignments
// This runbook allows admins to re-apply Customer Admin RBAC assignments on-demand
// Naming follows RFC-42 convention: kebab-case with {action}-{target} pattern
resource rbacCustomerAdminRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (!empty(customerAdminObjectId)) {
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

// Customer Admin Runbook draft content will be uploaded via deployment script below

// Automation Runbook for Publisher Admin RBAC role assignments
// This runbook allows admins to re-apply Publisher Admin RBAC assignments on-demand
// Only created for managed applications
// Naming follows RFC-42 convention: kebab-case with {action}-{target} pattern
resource rbacPublisherAdminRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (isManagedApplication && !empty(publisherAdminObjectId)) {
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

// Publisher Admin Runbook draft content will be uploaded via deployment script below

// ============================================================================
// UPLOAD AND PUBLISH RUNBOOKS
// Deployment script to upload runbook content and publish all runbooks
// Runbook content cannot be set via Bicep draft/content resource, so we use Azure CLI
// This ensures runbooks are immediately available for execution without manual publishing
// ============================================================================

var uploadRunbooksForceUpdateTagValue = guid(resourceGroup().id, automationId, 'upload-rbac-runbooks')
var uploadRunbooksScriptNameSuffix = substring(uploadRunbooksForceUpdateTagValue, 0, 8)
var uploadRunbooksScriptName = 'upload-rbac-runbooks-${uploadRunbooksScriptNameSuffix}'

// Deployment script to upload runbook content and publish all RBAC runbooks
resource uploadAndPublishRbacRunbooks 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: uploadRunbooksScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: uploadRunbooksForceUpdateTagValue
    retentionInterval: 'PT1H'
    azPowerShellVersion: '11.0'
    scriptContent: '''
      $ErrorActionPreference = "Stop"
      
      $AutomationAccountName = "${automationName}"
      $ResourceGroupName = "${resourceGroup().name}"
      $HasCustomerAdmin = "$env:HAS_CUSTOMER_ADMIN"
      $IsManagedApp = "$env:IS_MANAGED_APPLICATION"
      $HasPublisherAdmin = "$env:HAS_PUBLISHER_ADMIN"
      
      # Create temporary files for runbook content
      $TempDir = $env:TEMP
      $UamiScriptPath = Join-Path $TempDir "assign-rbac-roles-uami.ps1"
      $CustomerAdminScriptPath = Join-Path $TempDir "assign-rbac-roles-admin.ps1"
      $PublisherAdminScriptPath = Join-Path $TempDir "assign-rbac-roles-publisher-admin.ps1"
      
      Write-Host "Uploading and publishing RBAC runbooks..." -ForegroundColor Cyan
      
      # Write UAMI script content to temp file from environment variable
      $env:UAMI_SCRIPT_CONTENT | Out-File -FilePath $UamiScriptPath -Encoding utf8
      
      # Upload and publish UAMI runbook
      Write-Host "Uploading content for assign-rbac-roles-uami runbook..." -ForegroundColor Yellow
      try {
        az automation runbook replace-content `
          --automation-account-name $AutomationAccountName `
          --resource-group $ResourceGroupName `
          --name assign-rbac-roles-uami `
          --content-path $UamiScriptPath `
          --output none 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
          Write-Host "Successfully uploaded content for assign-rbac-roles-uami" -ForegroundColor Green
          
          Write-Host "Publishing assign-rbac-roles-uami runbook..." -ForegroundColor Yellow
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
        } else {
          Write-Warning "Failed to upload content for assign-rbac-roles-uami (exit code: $LASTEXITCODE)"
        }
      } catch {
        Write-Warning "Failed to upload/publish assign-rbac-roles-uami: $_"
      }
      
      # Upload and publish Customer Admin runbook (if customerAdminObjectId is provided)
      if ($HasCustomerAdmin -eq "True") {
        # Write Customer Admin script content to temp file from environment variable
        $env:CUSTOMER_ADMIN_SCRIPT_CONTENT | Out-File -FilePath $CustomerAdminScriptPath -Encoding utf8
        
        Write-Host "Uploading content for assign-rbac-roles-admin runbook..." -ForegroundColor Yellow
        try {
          az automation runbook replace-content `
            --automation-account-name $AutomationAccountName `
            --resource-group $ResourceGroupName `
            --name assign-rbac-roles-admin `
            --content-path $CustomerAdminScriptPath `
            --output none 2>&1 | Out-Null
          if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully uploaded content for assign-rbac-roles-admin" -ForegroundColor Green
            
            Write-Host "Publishing assign-rbac-roles-admin runbook..." -ForegroundColor Yellow
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
          } else {
            Write-Warning "Failed to upload content for assign-rbac-roles-admin (exit code: $LASTEXITCODE)"
          }
        } catch {
          Write-Warning "Failed to upload/publish assign-rbac-roles-admin: $_"
        }
      } else {
        Write-Host "Skipping assign-rbac-roles-admin (customerAdminObjectId not provided)" -ForegroundColor Gray
      }
      
      # Upload and publish Publisher Admin runbook (if managed application and publisherAdminObjectId is provided)
      if ($IsManagedApp -eq "True" -and $HasPublisherAdmin -eq "True") {
        # Write Publisher Admin script content to temp file from environment variable
        $env:PUBLISHER_ADMIN_SCRIPT_CONTENT | Out-File -FilePath $PublisherAdminScriptPath -Encoding utf8
        
        Write-Host "Uploading content for assign-rbac-roles-publisher-admin runbook..." -ForegroundColor Yellow
        try {
          az automation runbook replace-content `
            --automation-account-name $AutomationAccountName `
            --resource-group $ResourceGroupName `
            --name assign-rbac-roles-publisher-admin `
            --content-path $PublisherAdminScriptPath `
            --output none 2>&1 | Out-Null
          if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully uploaded content for assign-rbac-roles-publisher-admin" -ForegroundColor Green
            
            Write-Host "Publishing assign-rbac-roles-publisher-admin runbook..." -ForegroundColor Yellow
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
          } else {
            Write-Warning "Failed to upload content for assign-rbac-roles-publisher-admin (exit code: $LASTEXITCODE)"
          }
        } catch {
          Write-Warning "Failed to upload/publish assign-rbac-roles-publisher-admin: $_"
        }
      } else {
        Write-Host "Skipping assign-rbac-roles-publisher-admin (not a managed application or publisherAdminObjectId not provided)" -ForegroundColor Gray
      }
      
      Write-Host "Runbook upload and publishing completed" -ForegroundColor Cyan
    '''
    supportingScriptUris: []
    timeout: 'PT15M'
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
      {
        name: 'UAMI_SCRIPT_CONTENT'
        value: rbacUamiScript
      }
      {
        name: 'CUSTOMER_ADMIN_SCRIPT_CONTENT'
        value: rbacCustomerAdminScript
      }
      {
        name: 'PUBLISHER_ADMIN_SCRIPT_CONTENT'
        value: rbacPublisherAdminScript
      }
    ]
  }
  dependsOn: [
    rbacUamiRunbook
    rbacCustomerAdminRunbook
    rbacPublisherAdminRunbook
  ]
}

// ============================================================================
// RBAC ASSIGNMENTS VIA RUNBOOKS
// RBAC assignments are not executed automatically during deployment
// Owner must manually execute the published runbooks to assign RBAC roles
// Runbooks are idempotent and can be executed multiple times safely
// ============================================================================
