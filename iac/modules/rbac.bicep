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

@description('Automation Account name.')
param automationName string

@description('Tags to apply.')
param tags object

// PowerShell scripts are located in scripts/ directory
// Runbooks are NOT created in Bicep per RFC-71 Section 12.2 (Automation Account deployed empty)
// Runbooks must be created manually after deployment using the scripts in scripts/ directory
// See README.md for instructions on creating, uploading content, and publishing runbooks

// Reference Automation Account
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: automationName
}

// ============================================================================
// RBAC ASSIGNMENTS VIA AUTOMATION RUNBOOKS
// All role assignments are performed by PowerShell scripts available as automation runbooks
// Runbooks are NOT created in Bicep - they must be created manually after deployment
// - assign-rbac-roles-uami.ps1 for UAMI role assignments
// - assign-rbac-roles-admin.ps1 for Customer Admin role assignments
//
// Per RFC-71 Section 12.2: "Automation Account is deployed empty (no runbooks embedded in Bicep)"
// Runbooks should be created manually or via post-deployment scripts
// ============================================================================
