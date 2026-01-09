targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('VM name.')
param vmName string

@description('Subnet ID for VM.')
param subnetId string

@description('Admin username for VM.')
param adminUsername string

@description('Admin password for VM (secure parameter).')
@secure()
param adminPassword string

@description('Key Vault name for storing VM admin password.')
param kvName string

@description('VM size.')
@allowed([
  'Standard_A1_v2'
  'Standard_A1'
  'Standard_A2_v2'
  'Standard_A4_v2'
  'Standard_B1s'
  'Standard_B2s'
  'Standard_B1ms'
  'Standard_B2ms'
])
param vmSize string

@description('VM image publisher (default: Canonical).')
param imagePublisher string = 'Canonical'

@description('VM image offer (default: 0001-com-ubuntu-server-jammy).')
param imageOffer string = '0001-com-ubuntu-server-jammy'

@description('VM image SKU (default: 22_04-lts-gen2).')
param imageSku string = '22_04-lts-gen2'

@description('VM image version (default: latest).')
param imageVersion string = 'latest'

@description('Tags to apply.')
param tags object

// Reference Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kvName
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
      adminPassword: adminPassword
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
