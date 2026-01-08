# PowerShell script to assign RBAC roles for Admin (Customer Administrator)
# This script is executed by Azure deploymentScripts resource or automation runbook
# Parameters are passed via environment variables or script parameters

param(
    [string]$ResourceGroupId = $env:RESOURCE_GROUP_ID,
    [string]$CustomerAdminObjectId = $env:CUSTOMER_ADMIN_OBJECT_ID,
    [string]$CustomerAdminPrincipalType = $env:CUSTOMER_ADMIN_PRINCIPAL_TYPE,
    [string]$KvId = $env:KV_ID,
    [string]$StorageId = $env:STORAGE_ID,
    [string]$AcrId = $env:ACR_ID,
    [string]$SearchId = $env:SEARCH_ID,
    [string]$AiId = $env:AI_ID,
    [string]$AutomationId = $env:AUTOMATION_ID
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Customer Admin RBAC role assignment script..."
Write-Host "Resource Group ID: $ResourceGroupId"
Write-Host "Customer Admin Object ID: $CustomerAdminObjectId"
Write-Host "Customer Admin Principal Type: $(if ([string]::IsNullOrEmpty($CustomerAdminPrincipalType)) { 'User (default)' } else { $CustomerAdminPrincipalType })"

# Validate required parameters
if ([string]::IsNullOrEmpty($ResourceGroupId)) {
    Write-Error "RESOURCE_GROUP_ID environment variable is required"
    exit 1
}

if ([string]::IsNullOrEmpty($CustomerAdminObjectId)) {
    Write-Error "CUSTOMER_ADMIN_OBJECT_ID environment variable is required"
    exit 1
}

# Role definition IDs
$roleDefinitions = @{
    Reader = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    KeyVaultSecretsUser = "4633458b-17de-408a-b874-0445c86b69e6"
    StorageBlobDataReader = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
    StorageQueueDataReader = "19e7f393-937e-4f77-808e-945a386e9b0a"
    StorageTableDataReader = "76199698-9eea-4c19-bc75-cec21354c015"
    AcrPull = "7f951dda-4ed3-4680-a7ca-43fe172d538d"
    SearchServiceReader = "88308d66-4209-4f3e-9b77-8200b49e9c22"
    CognitiveServicesUser = "a97b65f3-24c7-4388-baec-2e87135dc908"
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
# ADMIN RBAC ASSIGNMENTS
# ============================================================================

Write-Host "`n=== Assigning Customer Admin RBAC Roles ===" -ForegroundColor Cyan

$customerAdminPrincipalType = if ([string]::IsNullOrEmpty($CustomerAdminPrincipalType)) { "User" } else { $CustomerAdminPrincipalType }

# Customer Admin: Reader on Resource Group
$customerAdminReaderName = Get-DeterministicGuid -Scope $ResourceGroupId -PrincipalId $CustomerAdminObjectId -Suffix "Reader"
New-RoleAssignment -Scope $ResourceGroupId `
    -RoleDefinitionId $roleDefinitions.Reader `
    -PrincipalId $CustomerAdminObjectId `
    -PrincipalType $customerAdminPrincipalType `
    -RoleAssignmentName $customerAdminReaderName

# Customer Admin: Key Vault Secrets User
if (![string]::IsNullOrEmpty($KvId)) {
    $customerAdminKvSecretsUserName = Get-DeterministicGuid -Scope $KvId -PrincipalId $CustomerAdminObjectId -Suffix "kv-secrets-user"
    New-RoleAssignment -Scope $KvId `
        -RoleDefinitionId $roleDefinitions.KeyVaultSecretsUser `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminKvSecretsUserName
}

# Customer Admin: Storage Blob Data Reader
if (![string]::IsNullOrEmpty($StorageId)) {
    $customerAdminStBlobReaderName = Get-DeterministicGuid -Scope $StorageId -PrincipalId $CustomerAdminObjectId -Suffix "st-blob-reader"
    New-RoleAssignment -Scope $StorageId `
        -RoleDefinitionId $roleDefinitions.StorageBlobDataReader `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminStBlobReaderName
    
    # Customer Admin: Storage Queue Data Reader
    $customerAdminStQueueReaderName = Get-DeterministicGuid -Scope $StorageId -PrincipalId $CustomerAdminObjectId -Suffix "st-queue-reader"
    New-RoleAssignment -Scope $StorageId `
        -RoleDefinitionId $roleDefinitions.StorageQueueDataReader `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminStQueueReaderName
    
    # Customer Admin: Storage Table Data Reader
    $customerAdminStTableReaderName = Get-DeterministicGuid -Scope $StorageId -PrincipalId $CustomerAdminObjectId -Suffix "st-table-reader"
    New-RoleAssignment -Scope $StorageId `
        -RoleDefinitionId $roleDefinitions.StorageTableDataReader `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminStTableReaderName
}

# Customer Admin: AcrPull
if (![string]::IsNullOrEmpty($AcrId)) {
    $customerAdminAcrPullName = Get-DeterministicGuid -Scope $AcrId -PrincipalId $CustomerAdminObjectId -Suffix "acr-pull"
    New-RoleAssignment -Scope $AcrId `
        -RoleDefinitionId $roleDefinitions.AcrPull `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminAcrPullName
}

# Customer Admin: Search Service Reader
if (![string]::IsNullOrEmpty($SearchId)) {
    $customerAdminSearchReaderName = Get-DeterministicGuid -Scope $SearchId -PrincipalId $CustomerAdminObjectId -Suffix "search-reader"
    New-RoleAssignment -Scope $SearchId `
        -RoleDefinitionId $roleDefinitions.SearchServiceReader `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminSearchReaderName
}

# Customer Admin: Cognitive Services User
if (![string]::IsNullOrEmpty($AiId)) {
    $customerAdminAiUserName = Get-DeterministicGuid -Scope $AiId -PrincipalId $CustomerAdminObjectId -Suffix "ai-user"
    New-RoleAssignment -Scope $AiId `
        -RoleDefinitionId $roleDefinitions.CognitiveServicesUser `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminAiUserName
}

# Customer Admin: Automation Job Operator
if (![string]::IsNullOrEmpty($AutomationId)) {
    $customerAdminAutomationJobOpName = Get-DeterministicGuid -Scope $AutomationId -PrincipalId $CustomerAdminObjectId -Suffix "automation-job-operator"
    New-RoleAssignment -Scope $AutomationId `
        -RoleDefinitionId $roleDefinitions.AutomationJobOperator `
        -PrincipalId $CustomerAdminObjectId `
        -PrincipalType $customerAdminPrincipalType `
        -RoleAssignmentName $customerAdminAutomationJobOpName
}

Write-Host "`nCustomer Admin RBAC role assignment script completed successfully" -ForegroundColor Green
