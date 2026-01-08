targetScope = 'resourceGroup'

@description('Deployment location.')
param location string = 'eastus'

@description('Public IP name.')
param pipName string = 'test-pip'

@description('Optional tags to apply.')
param tags object = {}

module publicIp '../../../iac/modules/public-ip.bicep' = {
  name: 'publicIp'
  params: {
    location: location
    pipName: pipName
    tags: tags
  }
}

output pipId string = publicIp.outputs.pipId

