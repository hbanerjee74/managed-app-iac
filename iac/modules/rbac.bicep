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

// PowerShell scripts are located in scripts/ directory
// Runbook content must be uploaded manually after deployment (see comments below)

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
    description: 'Assigns all RBAC roles for UAMI. Can be run by admins to re-apply UAMI RBAC assignments. Parameters: ResourceGroupId, UamiPrincipalId, UamiId, LawId, LawName, KvId, StorageId, AcrId, SearchId, AiId, AutomationId.'
  }
  dependsOn: [
    automationAccount
  ]
}

// UAMI Runbook content must be uploaded manually after deployment (see instructions below)

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

// Customer Admin Runbook content must be uploaded manually after deployment (see instructions below)

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

// Publisher Admin Runbook content must be uploaded manually after deployment (see instructions below)

// ============================================================================
// ============================================================================
// RUNBOOK CONTENT UPLOAD
// Runbook content must be uploaded and published manually after deployment
// Use the following Azure CLI commands:
//
// For assign-rbac-roles-uami:
//   az automation runbook replace-content \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name assign-rbac-roles-uami \
//     --content-path scripts/assign-rbac-roles-uami.ps1
//   az automation runbook publish \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name assign-rbac-roles-uami
//
// For assign-rbac-roles-admin (if customerAdminObjectId is provided):
//   az automation runbook replace-content \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name assign-rbac-roles-admin \
//     --content-path scripts/assign-rbac-roles-admin.ps1
//   az automation runbook publish \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name assign-rbac-roles-admin
//
// For assign-rbac-roles-publisher-admin (if managed application and publisherAdminObjectId is provided):
//   az automation runbook replace-content \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name assign-rbac-roles-publisher-admin \
//     --content-path scripts/assign-rbac-roles-publisher-admin.ps1
//   az automation runbook publish \
//     --automation-account-name <automation-account-name> \
//     --resource-group <resource-group> \
//     --name assign-rbac-roles-publisher-admin
// ============================================================================

// ============================================================================
// RBAC ASSIGNMENTS VIA RUNBOOKS
// RBAC assignments are not executed automatically during deployment
// Owner must manually execute the published runbooks to assign RBAC roles
// Runbooks are idempotent and can be executed multiple times safely
// ============================================================================
