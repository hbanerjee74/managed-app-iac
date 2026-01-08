targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Application Gateway name.')
param agwName string

@description('Public IP resource ID.')
param pipId string

@description('WAF Policy resource ID.')
param wafPolicyId string

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
            id: pipId
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
      {
        name: 'http-port'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'placeholder-pool'
        properties: {
          backendAddresses: []
        }
      }
    ]
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
    httpListeners: [
      {
        name: 'placeholder-listener'
        properties: {
          frontendIPConfiguration: {
            id: '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/applicationGateways/${agwName}/frontendIPConfigurations/appgw-feip'
          }
          frontendPort: {
            id: '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/applicationGateways/${agwName}/frontendPorts/http-port'
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'placeholder-rule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/applicationGateways/${agwName}/httpListeners/placeholder-listener'
          }
          backendAddressPool: {
            id: '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/applicationGateways/${agwName}/backendAddressPools/placeholder-pool'
          }
          backendHttpSettings: {
            id: '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/applicationGateways/${agwName}/backendHttpSettingsCollection/default-setting'
          }
        }
      }
    ]
    probes: []
    firewallPolicy: {
      id: wafPolicyId
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
