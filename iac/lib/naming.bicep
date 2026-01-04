targetScope = 'subscription'

@description('Resource group name used as seed for deterministic nanoid generation.')
param resourceGroupName string

@description('Logical purpose string to include in names (e.g., platform).')
param purpose string = 'platform'

// helper to build deterministic nanoids per resource type
param seedPrefix string = resourceGroupName

func nano16(seed string, suffix string) string => toLower('${substring(uniqueString('${seed}-${suffix}-a'), 0, 8)}${substring(uniqueString('${seed}-${suffix}-b'), 0, 8)}')
func nano8(seed string, suffix string) string => toLower(substring(uniqueString('${seed}-${suffix}-st'), 0, 8))

var names = {
  uami: 'vd-uami-${purpose}-${nano16(seedPrefix, 'uami')}'
  vnet: 'vd-vnet-${purpose}-${nano16(seedPrefix, 'vnet')}'
  nsgAppgw: 'vd-nsg-appgw-${nano16(seedPrefix, 'nsgappgw')}'
  nsgAks: 'vd-nsg-aks-${nano16(seedPrefix, 'nsgaks')}'
  nsgAppsvc: 'vd-nsg-appsvc-${nano16(seedPrefix, 'nsgappsvc')}'
  nsgPe: 'vd-nsg-pe-${nano16(seedPrefix, 'nsgpe')}'
  kv: 'vd-kv-${purpose}-${nano16(seedPrefix, 'kv')}'
  storage: 'vdst${purpose}${nano8(seedPrefix, 'st')}'
  acr: 'vd-acr-${purpose}-${nano16(seedPrefix, 'acr')}'
  law: 'vd-law-${purpose}-${nano16(seedPrefix, 'law')}'
  asp: 'vd-asp-${purpose}-${nano16(seedPrefix, 'asp')}'
  appApi: 'vd-app-api-${nano16(seedPrefix, 'appapi')}'
  appUi: 'vd-app-ui-${nano16(seedPrefix, 'appui')}'
  funcOps: 'vd-func-ops-${nano16(seedPrefix, 'func')}'
  agw: 'vd-agw-${purpose}-${nano16(seedPrefix, 'agw')}'
  pipAgw: 'vd-pip-agw-${nano16(seedPrefix, 'pipagw')}'
  psql: 'vd-psql-${purpose}-${nano16(seedPrefix, 'psql')}'
  search: 'vd-search-${purpose}-${nano16(seedPrefix, 'search')}'
  ai: 'vd-ai-${purpose}-${nano16(seedPrefix, 'ai')}'
  automation: 'vd-aa-${purpose}-${nano16(seedPrefix, 'aa')}'
  logic: 'vd-logic-${purpose}-${nano16(seedPrefix, 'logic')}'
}

output names object = names
