# PowerShell script to assign RBAC roles for UAMI (User-Assigned Managed Identity)
# This script is executed by Azure deploymentScripts resource or automation runbook
# Parameters are passed via environment variables or script parameters

param(
    [string]$ResourceGroupId = $env:RESOURCE_GROUP_ID,
    [string]$UamiPrincipalId = $env:UAMI_PRINCIPAL_ID,
    [string]$UamiId = $env:UAMI_ID,
    [string]$LawId = $env:LAW_ID,
    [string]$LawName = $env:LAW_NAME,
    [string]$KvId = $env:KV_ID,
    [string]$StorageId = $env:STORAGE_ID,
    [string]$AcrId = $env:ACR_ID,
    [string]$SearchId = $env:SEARCH_ID,
    [string]$AiId = $env:AI_ID,
    [string]$AutomationId = $env:AUTOMATION_ID
)

$ErrorActionPreference = "Stop"

Write-Host "Starting UAMI RBAC role assignment script..."
Write-Host "Resource Group ID: $ResourceGroupId"
Write-Host "UAMI Principal ID: $UamiPrincipalId"
Write-Host "UAMI ID: $UamiId"

# Validate required parameters
if ([string]::IsNullOrEmpty($ResourceGroupId)) {
    Write-Error "RESOURCE_GROUP_ID environment variable is required"
    exit 1
}

if ([string]::IsNullOrEmpty($UamiPrincipalId)) {
    Write-Error "UAMI_PRINCIPAL_ID environment variable is required"
    exit 1
}

if ([string]::IsNullOrEmpty($UamiId)) {
    Write-Error "UAMI_ID environment variable is required"
    exit 1
}

# Role definition IDs
$roleDefinitions = @{
    Contributor = "b24988ac-6180-42a0-ab88-20f7382dd24c"
    LogAnalyticsContributor = "73c42c96-874c-492b-b04d-ab87d138a893"
    KeyVaultSecretsOfficer = "b86a8fe4-44ce-4948-aee5-eccb2c155cd7"
    StorageBlobDataContributor = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    StorageQueueDataContributor = "974c5e8b-45b9-4653-ba55-5f855dd0fb88"
    StorageTableDataContributor = "0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3"
    AcrPull = "7f951dda-4ed3-4680-a7ca-43fe172d538d"
    AcrPush = "8311e382-0749-4cb8-b61a-304f252e45ec"
    SearchServiceContributor = "de139f84-1756-47ae-9be6-808fbbe84772"
    CognitiveServicesContributor = "a97b65f3-24c7-4388-baec-2e87135dc908"
    AutomationJobOperator = "4fe576fe-1146-4730-92eb-48519fa6bf9f"
}

function Get-DeterministicGuid {
    param(
        [string]$Scope,
        [string]$PrincipalId,
        [string]$Suffix
    )
    
    # Generate deterministic GUID similar to Bicep guid() function
    # Bicep's guid() uses a deterministic algorithm based on the input string
    # We'll use MD5 hash to create a deterministic GUID from the inputs
    $inputString = "$Scope-$PrincipalId-$Suffix"
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($inputString))
    
    # Create a GUID from the MD5 hash (16 bytes)
    # GUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    $guidBytes = New-Object byte[] 16
    [Array]::Copy($hash, 0, $guidBytes, 0, 16)
    
    # Set version bits (version 4 UUID uses bits 12-15 = 0100)
    $guidBytes[6] = ($guidBytes[6] -band 0x0F) -bor 0x40
    # Set variant bits (bits 6-7 of byte 8 = 10)
    $guidBytes[8] = ($guidBytes[8] -band 0x3F) -bor 0x80
    
    $guid = New-Object System.Guid(,$guidBytes)
    return $guid.ToString()
}

function New-RoleAssignment {
    param(
        [string]$Scope,
        [string]$RoleDefinitionId,
        [string]$PrincipalId,
        [string]$PrincipalType,
        [string]$RoleAssignmentName
    )
    
    Write-Host "Assigning role $RoleAssignmentName at scope $Scope..."
    
    try {
        # Check if role assignment already exists
        $existing = az role assignment list --scope $Scope --assignee $PrincipalId --role $RoleDefinitionId --query "[?name=='$RoleAssignmentName']" -o json | ConvertFrom-Json
        
        if ($existing -and $existing.Count -gt 0) {
            Write-Host "Role assignment $RoleAssignmentName already exists, skipping..." -ForegroundColor Yellow
            return
        }
        
        # Build Azure CLI command arguments
        $azArgs = @(
            "role", "assignment", "create",
            "--scope", $Scope,
            "--role", $RoleDefinitionId,
            "--assignee", $PrincipalId,
            "--assignee-principal-type", $PrincipalType,
            "--name", $RoleAssignmentName
        )
        
        # Create role assignment
        az @azArgs | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully assigned role $RoleAssignmentName" -ForegroundColor Green
        } else {
            Write-Warning "Failed to assign role $RoleAssignmentName (exit code: $LASTEXITCODE)"
        }
    } catch {
        Write-Warning "Error assigning role $RoleAssignmentName : $_"
    }
}

# ============================================================================
# UAMI RBAC ASSIGNMENTS
# ============================================================================

Write-Host "`n=== Assigning UAMI RBAC Roles ===" -ForegroundColor Cyan

# UAMI: Contributor on Resource Group
$rgContributorName = Get-DeterministicGuid -Scope $ResourceGroupId -PrincipalId $UamiId -Suffix "Contributor"
New-RoleAssignment -Scope $ResourceGroupId `
    -RoleDefinitionId $roleDefinitions.Contributor `
    -PrincipalId $UamiPrincipalId `
    -PrincipalType "ServicePrincipal" `
    -RoleAssignmentName $rgContributorName

# UAMI: Log Analytics Contributor (if LAW provided)
if (![string]::IsNullOrEmpty($LawId) -and ![string]::IsNullOrEmpty($LawName)) {
    $lawContributorName = Get-DeterministicGuid -Scope $LawId -PrincipalId $UamiId -Suffix "LAW-Contrib"
    New-RoleAssignment -Scope $LawId `
        -RoleDefinitionId $roleDefinitions.LogAnalyticsContributor `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $lawContributorName
}

# UAMI: Key Vault Secrets Officer
if (![string]::IsNullOrEmpty($KvId)) {
    $kvSecretsOfficerName = Get-DeterministicGuid -Scope $KvId -PrincipalId $UamiPrincipalId -Suffix "kv-secret-officer"
    New-RoleAssignment -Scope $KvId `
        -RoleDefinitionId $roleDefinitions.KeyVaultSecretsOfficer `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $kvSecretsOfficerName
}

# UAMI: Storage Blob Data Contributor
if (![string]::IsNullOrEmpty($StorageId)) {
    $stBlobContribName = Get-DeterministicGuid -Scope $StorageId -PrincipalId $UamiPrincipalId -Suffix "st-blob-data-contrib"
    New-RoleAssignment -Scope $StorageId `
        -RoleDefinitionId $roleDefinitions.StorageBlobDataContributor `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $stBlobContribName
    
    # UAMI: Storage Queue Data Contributor
    $stQueueContribName = Get-DeterministicGuid -Scope $StorageId -PrincipalId $UamiPrincipalId -Suffix "st-queue-data-contrib"
    New-RoleAssignment -Scope $StorageId `
        -RoleDefinitionId $roleDefinitions.StorageQueueDataContributor `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $stQueueContribName
    
    # UAMI: Storage Table Data Contributor
    $stTableContribName = Get-DeterministicGuid -Scope $StorageId -PrincipalId $UamiPrincipalId -Suffix "st-table-data-contrib"
    New-RoleAssignment -Scope $StorageId `
        -RoleDefinitionId $roleDefinitions.StorageTableDataContributor `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $stTableContribName
}

# UAMI: AcrPull
if (![string]::IsNullOrEmpty($AcrId)) {
    $acrPullName = Get-DeterministicGuid -Scope $AcrId -PrincipalId $UamiPrincipalId -Suffix "acr-pull"
    New-RoleAssignment -Scope $AcrId `
        -RoleDefinitionId $roleDefinitions.AcrPull `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $acrPullName
    
    # UAMI: AcrPush
    $acrPushName = Get-DeterministicGuid -Scope $AcrId -PrincipalId $UamiPrincipalId -Suffix "acr-push"
    New-RoleAssignment -Scope $AcrId `
        -RoleDefinitionId $roleDefinitions.AcrPush `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $acrPushName
}

# UAMI: Search Service Contributor
if (![string]::IsNullOrEmpty($SearchId)) {
    $searchContribName = Get-DeterministicGuid -Scope $SearchId -PrincipalId $UamiPrincipalId -Suffix "search-contrib"
    New-RoleAssignment -Scope $SearchId `
        -RoleDefinitionId $roleDefinitions.SearchServiceContributor `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $searchContribName
}

# UAMI: Cognitive Services Contributor
if (![string]::IsNullOrEmpty($AiId)) {
    $aiContribName = Get-DeterministicGuid -Scope $AiId -PrincipalId $UamiPrincipalId -Suffix "ai-contrib"
    New-RoleAssignment -Scope $AiId `
        -RoleDefinitionId $roleDefinitions.CognitiveServicesContributor `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $aiContribName
}

# UAMI: Automation Job Operator
if (![string]::IsNullOrEmpty($AutomationId)) {
    $automationJobOpName = Get-DeterministicGuid -Scope $AutomationId -PrincipalId $UamiPrincipalId -Suffix "automation-job-operator"
    New-RoleAssignment -Scope $AutomationId `
        -RoleDefinitionId $roleDefinitions.AutomationJobOperator `
        -PrincipalId $UamiPrincipalId `
        -PrincipalType "ServicePrincipal" `
        -RoleAssignmentName $automationJobOpName
}

Write-Host "`nUAMI RBAC role assignment script completed successfully" -ForegroundColor Green
