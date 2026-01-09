targetScope = 'resourceGroup'

@description('Key Vault name.')
param kvName string

@description('VM admin username.')
param vmAdminUsername string

@description('VM admin password.')
@secure()
param vmAdminPassword string

@description('PostgreSQL admin username.')
param psqlAdminUsername string

@description('PostgreSQL admin password.')
@secure()
param psqlAdminPassword string

// Reference Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kvName
}

// Create VM admin username secret in Key Vault
resource vmAdminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'vm-admin-username'
  properties: {
    value: vmAdminUsername
  }
  dependsOn: [
    kv
  ]
}

// Create VM admin password secret in Key Vault
resource vmAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'vm-admin-password'
  properties: {
    value: vmAdminPassword
  }
  dependsOn: [
    kv
  ]
}

// Create PostgreSQL admin username secret in Key Vault
resource psqlAdminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'psql-admin-username'
  properties: {
    value: psqlAdminUsername
  }
  dependsOn: [
    kv
  ]
}

// Create PostgreSQL admin password secret in Key Vault
resource psqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'psql-admin-password'
  properties: {
    value: psqlAdminPassword
  }
  dependsOn: [
    kv
  ]
}

// Output secret names for use in other modules
output vmAdminUsernameSecretName string = vmAdminUsernameSecret.name
output vmAdminPasswordSecretName string = vmAdminPasswordSecret.name
output psqlAdminUsernameSecretName string = psqlAdminUsernameSecret.name
output psqlAdminPasswordSecretName string = psqlAdminPasswordSecret.name
