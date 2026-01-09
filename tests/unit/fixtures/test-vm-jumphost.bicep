targetScope = 'resourceGroup'

// Test wrapper for vm-jumphost module
// Depends on: network, kv, identity, diagnostics, dns

@description('Resource group name for naming seed.')
param resourceGroupName string

@description('Azure region for deployment (RFC-64: location).')
param location string

// Include naming module
module naming '../../../iac/lib/naming.bicep' = {
  name: 'naming'
  params: {
    resourceGroupName: resourceGroupName
  }
}

// Mock dependency outputs
var mockNetworkOutputs = {
  subnetPeId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-pe'
}

var mockDiagnosticsOutputs = {
  lawId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law'
}

var mockDnsOutputs = {
  zoneIds: {
    vault: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
  }
}

// Create Key Vault dependency (needed for secret creation)
module kv '../../../iac/modules/kv.bicep' = {
  name: 'kv'
  params: {
    location: location
    kvName: naming.outputs.names.kv
    subnetPeId: mockNetworkOutputs.subnetPeId
    lawId: mockDiagnosticsOutputs.lawId
    zoneIds: mockDnsOutputs.zoneIds
    peKvName: naming.outputs.names.peKv
    peKvDnsName: naming.outputs.names.peKvDns
    diagKvName: naming.outputs.names.diagKv
    tags: {}
  }
}

// Create secrets module for admin credentials
module secrets '../../../iac/modules/secrets.bicep' = {
  name: 'secrets'
  dependsOn: [
    kv
  ]
  params: {
    kvName: naming.outputs.names.kv
    vmAdminUsername: 'azureuser'
    vmAdminPassword: 'test-password-123'
    psqlAdminUsername: 'psqladmin'
    psqlAdminPassword: 'test-psql-password-123'
  }
}

// Module under test
module vmJumphost '../../../iac/modules/vm-jumphost.bicep' = {
  name: 'vm-jumphost'
  dependsOn: [
    kv
    secrets
  ]
  params: {
    location: location
    vmName: naming.outputs.names.vm
    subnetId: mockNetworkOutputs.subnetPeId
    kvName: naming.outputs.names.kv
    adminUsername: 'azureuser'
    adminPassword: 'test-password-123'
    vmAdminUsernameSecretName: secrets.outputs.vmAdminUsernameSecretName
    vmAdminPasswordSecretName: secrets.outputs.vmAdminPasswordSecretName
    vmSize: 'Standard_B2s'
    imagePublisher: 'Canonical'
    imageOffer: '0001-com-ubuntu-server-jammy'
    imageSku: '22_04-lts-gen2'
    imageVersion: 'latest'
    tags: {}
  }
}

output vmId string = vmJumphost.outputs.vmId
output vmName string = vmJumphost.outputs.vmName
output vmPrivateIp string = vmJumphost.outputs.vmPrivateIp
output names object = naming.outputs.names
