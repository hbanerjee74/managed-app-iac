targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('VM name.')
param vmName string

@description('Subnet ID for VM.')
param subnetId string

@description('Admin username for VM.')
param adminUsername string = 'azureuser'

@description('Admin password for VM (secure parameter, auto-generated if not provided).')
@secure()
param adminPassword string = ''

@description('Key Vault name for storing VM admin password.')
param kvName string

@description('VM size (default: Standard_B2s).')
param vmSize string = 'Standard_B2s'

@description('VM image publisher (default: Canonical).')
param imagePublisher string = 'Canonical'

@description('VM image offer (default: 0001-com-ubuntu-server-jammy).')
param imageOffer string = '0001-com-ubuntu-server-jammy'

@description('VM image SKU (default: 22_04-lts-gen2).')
param imageSku string = '22_04-lts-gen2'

@description('VM image version (default: latest).')
param imageVersion string = 'latest'

@description('Optional tags to apply.')
param tags object = {}

// Reference Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kvName
}

// Generate secure password if not provided
var vmAdminPasswordValue = empty(adminPassword) ? guid(subscription().id, kv.id, 'vm-admin-password') : adminPassword

// Create VM admin password secret in Key Vault
resource vmAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'vm-admin-password'
  properties: {
    value: vmAdminPasswordValue
  }
}

// Network interface for VM
resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Virtual Machine - created in stopped state (deallocated)
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        caching: 'ReadWrite'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: vmAdminPasswordValue
      linuxConfiguration: {
        disablePasswordAuthentication: false
        ssh: {
          publicKeys: []
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Note: VM is created in deallocated (stopped) state by default.
// To start the VM, use: az vm start --resource-group <rg> --name <vm-name>

output vmId string = vm.id
output vmName string = vm.name
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
