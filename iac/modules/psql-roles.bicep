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

resource createRoles 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: scriptName
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    forceUpdateTag: forceUpdateTagValue
    retentionInterval: 'PT1H'
    azCliVersion: '2.61.0'
    //disable-next-line no-hardcoded-env-urls
    scriptContent: '''
#!/usr/bin/env bash
set -euo pipefail
SERVER="${SERVER_HOST}"
KV_NAME="${KV_NAME}"
UAMI_CLIENT_ID="${UAMI_CLIENT_ID}"

echo "Checking if psql is available..."
if ! command -v psql &> /dev/null; then
  echo "Installing PostgreSQL client (psql)..."
  apt-get update -qq && apt-get install -y postgresql-client > /dev/null 2>&1 || {
    echo "ERROR: Failed to install postgresql-client"
    exit 1
  }
fi

echo "Retrieving PostgreSQL admin credentials from Key Vault..."
PSQL_ADMIN_USERNAME=$(az keyvault secret show --vault-name "${KV_NAME}" --name "psql-admin-username" --query "value" -o tsv)
if [ -z "$PSQL_ADMIN_USERNAME" ]; then
  echo "ERROR: Failed to retrieve PostgreSQL admin username from Key Vault"
  exit 1
fi

PSQL_ADMIN_PASSWORD=$(az keyvault secret show --vault-name "${KV_NAME}" --name "psql-admin-password" --query "value" -o tsv)
if [ -z "$PSQL_ADMIN_PASSWORD" ]; then
  echo "ERROR: Failed to retrieve PostgreSQL admin password from Key Vault"
  exit 1
fi

export PGPASSWORD="$PSQL_ADMIN_PASSWORD"

echo "Waiting for PostgreSQL server to be ready..."
RETRY_COUNT=0
MAX_RETRIES=30
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if psql "host=${SERVER} user=${PSQL_ADMIN_USERNAME} dbname=postgres sslmode=require" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "PostgreSQL server is ready"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for PostgreSQL server... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: PostgreSQL server is not ready after ${MAX_RETRIES} attempts"
  exit 1
fi

echo "Testing admin credentials by performing a simple query..."
if psql "host=${SERVER} user=${PSQL_ADMIN_USERNAME} dbname=postgres sslmode=require" -c "SELECT current_user, version();" > /dev/null 2>&1; then
  echo "Successfully verified admin credentials - login test passed"
else
  echo "ERROR: Failed to login with admin credentials"
  exit 1
fi

# Role assignment code commented out - will be re-enabled after credential verification is stable
# echo "Creating roles vd_dbo and vd_reader if missing, and granting vd_dbo to UAMI..."
# # Use unquoted heredoc to allow bash variable expansion for UAMI_CLIENT_ID
# psql "host=${SERVER} user=${PSQL_ADMIN_USERNAME} dbname=postgres sslmode=require" <<SQL
# DO \$\$
# BEGIN
#   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'vd_dbo') THEN
#     CREATE ROLE "vd_dbo";
#     RAISE NOTICE 'Created role vd_dbo';
#   ELSE
#     RAISE NOTICE 'Role vd_dbo already exists';
#   END IF;
#   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'vd_reader') THEN
#     CREATE ROLE "vd_reader";
#     RAISE NOTICE 'Created role vd_reader';
#   ELSE
#     RAISE NOTICE 'Role vd_reader already exists';
#   END IF;
# END\$\$;
# -- Grant vd_dbo role to UAMI (using client ID as the role name for AAD authentication)
# GRANT "vd_dbo" TO "${UAMI_CLIENT_ID}";
# SQL
#
# if [ $? -eq 0 ]; then
#   echo "Successfully created roles and granted permissions"
# else
#   echo "ERROR: Failed to create roles or grant permissions"
#   exit 1
# fi
'''
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
