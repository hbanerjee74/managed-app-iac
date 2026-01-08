targetScope = 'resourceGroup'

@description('Deployment location.')
param location string = 'eastus'

@description('WAF Policy name.')
param wafPolicyName string = 'test-waf-policy'

@description('Customer IP ranges for WAF allowlist.')
param customerIpRanges array = [
  '1.2.3.4/32'
]

@description('Publisher IP ranges for WAF allowlist.')
param publisherIpRanges array = [
  '5.6.7.8/32'
]

@description('Optional tags to apply.')
param tags object = {}

module wafPolicy '../../../iac/modules/waf-policy.bicep' = {
  name: 'wafPolicy'
  params: {
    location: location
    wafPolicyName: wafPolicyName
    customerIpRanges: customerIpRanges
    publisherIpRanges: publisherIpRanges
    tags: tags
  }
}

output wafPolicyId string = wafPolicy.outputs.wafPolicyId

