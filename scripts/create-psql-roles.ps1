# PowerShell script to create PostgreSQL roles and grant permissions
# This script is executed by Azure deploymentScripts resource
# Parameters are passed via environment variables:
#   SERVER_HOST - PostgreSQL server hostname (e.g., servername.postgres.database.azure.com)
#   KV_NAME - Key Vault name for retrieving admin credentials
#   UAMI_CLIENT_ID - Client ID of the User-Assigned Managed Identity

param(
    [string]$ServerHost = $env:SERVER_HOST,
    [string]$KvName = $env:KV_NAME,
    [string]$UamiClientId = $env:UAMI_CLIENT_ID
)

$ErrorActionPreference = "Stop"

Write-Host "Starting PostgreSQL role creation script..."
Write-Host "Server Host: $ServerHost"
Write-Host "Key Vault Name: $KvName"
Write-Host "UAMI Client ID: $UamiClientId"

# Validate required parameters
if ([string]::IsNullOrEmpty($ServerHost)) {
    Write-Error "SERVER_HOST environment variable is required"
    exit 1
}

if ([string]::IsNullOrEmpty($KvName)) {
    Write-Error "KV_NAME environment variable is required"
    exit 1
}

if ([string]::IsNullOrEmpty($UamiClientId)) {
    Write-Error "UAMI_CLIENT_ID environment variable is required"
    exit 1
}

# Check if psql is available
Write-Host "Checking if psql is available..."
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    Write-Host "psql not found in PATH. Attempting to install PostgreSQL client..."
    
    # Try to install psql using Chocolatey (if available) or download directly
    # Note: Azure deploymentScripts PowerShell runs on Windows containers
    # For production, consider pre-installing psql or using Azure CLI deploymentScripts instead
    try {
        # Check if Chocolatey is available
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoPath) {
            Write-Host "Installing PostgreSQL client using Chocolatey..."
            choco install postgresql --version=16.0.0 -y --no-progress
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $psqlPath = Get-Command psql -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Warning "Could not install psql via Chocolatey: $_"
    }
    
    # Verify psql is now available
    if (-not $psqlPath) {
        Write-Error "psql command not found and could not be installed. This script requires psql to be available."
        Write-Error "For Azure deploymentScripts, consider using AzureCLI kind (Linux) which has psql pre-installed, or ensure psql is pre-installed in the deploymentScripts environment."
        exit 1
    }
    
    Write-Host "Successfully verified psql is available"
}

# Retrieve PostgreSQL admin credentials from Key Vault
Write-Host "Retrieving PostgreSQL admin credentials from Key Vault..."
try {
    $psqlAdminUsername = az keyvault secret show --vault-name $KvName --name "psql-admin-username" --query "value" -o tsv
    if ([string]::IsNullOrEmpty($psqlAdminUsername)) {
        Write-Error "Failed to retrieve PostgreSQL admin username from Key Vault"
        exit 1
    }
    
    $psqlAdminPassword = az keyvault secret show --vault-name $KvName --name "psql-admin-password" --query "value" -o tsv
    if ([string]::IsNullOrEmpty($psqlAdminPassword)) {
        Write-Error "Failed to retrieve PostgreSQL admin password from Key Vault"
        exit 1
    }
    
    Write-Host "Successfully retrieved admin credentials from Key Vault"
} catch {
    Write-Error "Error retrieving credentials from Key Vault: $_"
    exit 1
}

# Set PGPASSWORD environment variable for psql
$env:PGPASSWORD = $psqlAdminPassword

# Wait for PostgreSQL server to be ready
Write-Host "Waiting for PostgreSQL server to be ready..."
$retryCount = 0
$maxRetries = 30
$serverReady = $false

while ($retryCount -lt $maxRetries) {
    try {
        $testQuery = psql "host=$ServerHost user=$psqlAdminUsername dbname=postgres sslmode=require" -c "SELECT 1;" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PostgreSQL server is ready"
            $serverReady = $true
            break
        }
    } catch {
        # Continue retrying
    }
    
    $retryCount++
    Write-Host "Waiting for PostgreSQL server... (attempt $retryCount/$maxRetries)"
    Start-Sleep -Seconds 10
}

if (-not $serverReady) {
    Write-Error "PostgreSQL server is not ready after $maxRetries attempts"
    exit 1
}

# Test admin credentials
Write-Host "Testing admin credentials by performing a simple query..."
try {
    $testResult = psql "host=$ServerHost user=$psqlAdminUsername dbname=postgres sslmode=require" -c "SELECT current_user, version();" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully verified admin credentials - login test passed"
    } else {
        Write-Error "Failed to login with admin credentials"
        exit 1
    }
} catch {
    Write-Error "Error testing admin credentials: $_"
    exit 1
}

# Create roles and grant permissions
Write-Host "Creating roles vd_dbo and vd_reader if missing, and granting vd_dbo to UAMI..."

$sqlScript = @"
DO `$\$`
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'vd_dbo') THEN
    CREATE ROLE "vd_dbo";
    RAISE NOTICE 'Created role vd_dbo';
  ELSE
    RAISE NOTICE 'Role vd_dbo already exists';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'vd_reader') THEN
    CREATE ROLE "vd_reader";
    RAISE NOTICE 'Created role vd_reader';
  ELSE
    RAISE NOTICE 'Role vd_reader already exists';
  END IF;
END`$\$`;
-- Grant vd_dbo role to UAMI (using client ID as the role name for AAD authentication)
GRANT "vd_dbo" TO "$UamiClientId";
"@

try {
    # Use psql with here-string input
    $sqlScript | psql "host=$ServerHost user=$psqlAdminUsername dbname=postgres sslmode=require"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully created roles and granted permissions"
    } else {
        Write-Error "Failed to create roles or grant permissions"
        exit 1
    }
} catch {
    Write-Error "Error executing SQL script: $_"
    exit 1
}

Write-Host "PostgreSQL role creation script completed successfully"
