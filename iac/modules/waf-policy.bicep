targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('WAF Policy name.')
param wafPolicyName string

@description('Customer IP ranges for WAF allowlist.')
param customerIpRanges array

@description('Tags to apply.')
param tags object

var wafRules = [
  // Customer allowlist (RFC-71: priority range 100-199)
  {
    name: 'Allow-Customer'
    priority: 1
    action: 'Allow'
    cidrs: customerIpRanges
  }
]

var wafAllowRules = [for rule in wafRules: {
  name: rule.name
  priority: rule.priority
  ruleType: 'MatchRule'
  action: rule.action
  state: 'Enabled'
  matchConditions: [
    {
      matchVariables: [
        {
          variableName: 'RemoteAddr'
        }
      ]
      operator: 'IPMatch'
      matchValues: rule.cidrs
    }
  ]
}]

var wafCustomRules = concat(wafAllowRules, [
  {
    name: 'Deny-All'
    priority: 2  // Deny all traffic after customer allowlist
    ruleType: 'MatchRule'
    action: 'Block'
    state: 'Enabled'
    matchConditions: [
      {
        matchVariables: [
          {
            variableName: 'RemoteAddr'
          }
        ]
        operator: 'IPMatch'
        matchValues: [
          '0.0.0.0/0'
        ]
      }
    ]
  }
])

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

output wafPolicyId string = agwPolicy.id

