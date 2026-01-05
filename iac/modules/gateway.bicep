targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Application Gateway name.')
param agwName string

@description('Public IP name for Application Gateway.')
param pipName string

@description('Customer IP ranges for WAF allowlist.')
param customerIpRanges array

@description('Publisher IP ranges for WAF allowlist.')
param publisherIpRanges array

@description('Application Gateway subnet ID.')
param subnetAppgwId string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('Application Gateway capacity (from RFC-64 appGwCapacity display).')
param appGwCapacity int = 1

@description('Application Gateway SKU (from RFC-64 appGwSku display).')
param appGwSku string = 'WAF_v2'

@description('Diagnostic setting name from naming helper.')
param diagAgwName string

@description('Optional tags to apply.')
param tags object = {}

resource pip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

var wafRules = [
  // Customer allowlist
  {
    name: 'Allow-Customer'
    priority: 100
    action: 'Allow'
    cidrs: customerIpRanges
  }
  // Publisher allowlist
  {
    name: 'Allow-Publisher'
    priority: 200
    action: 'Allow'
    cidrs: publisherIpRanges
  }
]

var wafAllowRules = [for rule in wafRules: {
  name: rule.name
  priority: rule.priority
  ruleType: 'MatchRule'
  action: rule.action
  matchConditions: [
    {
      matchVariables: [
        {
          variableName: 'RemoteAddr'
        }
      ]
      operator: 'IPMatch'
      negationCondition: false
      matchValues: rule.cidrs
    }
  ]
}]

var wafCustomRules = concat(wafAllowRules, [
  {
    name: 'Deny-All'
    priority: 1000
    ruleType: 'MatchRule'
    action: 'Block'
    matchConditions: [
      {
        matchVariables: [
          {
            variableName: 'RemoteAddr'
          }
        ]
        operator: 'IPMatch'
        negationCondition: false
        matchValues: [
          '0.0.0.0/0'
        ]
      }
    ]
  }
])

var wafPolicyName = '${agwName}-waf'

resource agwPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-09-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
      requestBodyCheck: true
    }
    customRules: wafCustomRules
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

resource appGw 'Microsoft.Network/applicationGateways@2021-08-01' = {
  name: agwName
  location: location
  tags: tags
  properties: {
    sku: {
      name: appGwSku
      tier: 'WAF_v2'
      capacity: appGwCapacity
    }
    enableHttp2: true
    gatewayIPConfigurations: [
      {
        name: 'appgw-ipconfig'
        properties: {
          subnet: {
            id: subnetAppgwId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appgw-feip'
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'https-port'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: []
    backendHttpSettingsCollection: [
      {
        name: 'default-setting'
        properties: {
          protocol: 'Https'
          port: 443
          pickHostNameFromBackendAddress: true
          requestTimeout: 60
          connectionDraining: {
            enabled: true
            drainTimeoutInSec: 60
          }
        }
      }
    ]
    httpListeners: []
    requestRoutingRules: []
    probes: []
    firewallPolicy: {
      id: agwPolicy.id
    }
  }
}

output appGwId string = appGw.id

resource appGwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagAgwName
  scope: appGw
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// TODO: deploy Application Gateway WAF_v2 with rules per PRD-30.
