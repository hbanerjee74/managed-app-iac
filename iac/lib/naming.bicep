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
  networkWatcher: 'vd-nw-${purpose}-${nano16(seedPrefix, 'nw')}'
  nsgAppgw: 'vd-nsg-appgw-${nano16(seedPrefix, 'nsgappgw')}'
  nsgAks: 'vd-nsg-aks-${nano16(seedPrefix, 'nsgaks')}'
  nsgAppsvc: 'vd-nsg-appsvc-${nano16(seedPrefix, 'nsgappsvc')}'
  nsgPe: 'vd-nsg-pe-${nano16(seedPrefix, 'nsgpe')}'
  flowLogAppgw: 'vd-flow-nsg-appgw-${purpose}-${nano16(seedPrefix, 'flowappgw')}'
  flowLogAks: 'vd-flow-nsg-aks-${purpose}-${nano16(seedPrefix, 'flowaks')}'
  flowLogAppsvc: 'vd-flow-nsg-appsvc-${purpose}-${nano16(seedPrefix, 'flowappsvc')}'
  flowLogPe: 'vd-flow-nsg-pe-${purpose}-${nano16(seedPrefix, 'flowpe')}'
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
  // Private endpoints per RFC-71 rtype 'pe'
  peKv: 'vd-pe-kv-${purpose}-${nano16(seedPrefix, 'pekv')}'
  peStBlob: 'vd-pe-st-blob-${purpose}-${nano16(seedPrefix, 'pestblob')}'
  peStQueue: 'vd-pe-st-queue-${purpose}-${nano16(seedPrefix, 'pestqueue')}'
  peStTable: 'vd-pe-st-table-${purpose}-${nano16(seedPrefix, 'pesttable')}'
  peAcr: 'vd-pe-acr-${purpose}-${nano16(seedPrefix, 'peacr')}'
  peAppApi: 'vd-pe-app-api-${purpose}-${nano16(seedPrefix, 'peappapi')}'
  peAppUi: 'vd-pe-app-ui-${purpose}-${nano16(seedPrefix, 'peappui')}'
  peFunc: 'vd-pe-func-${purpose}-${nano16(seedPrefix, 'pefunc')}'
  peSearch: 'vd-pe-search-${purpose}-${nano16(seedPrefix, 'pesearch')}'
  peAi: 'vd-pe-ai-${purpose}-${nano16(seedPrefix, 'peai')}'
  peAutomation: 'vd-pe-aa-${purpose}-${nano16(seedPrefix, 'peaa')}'
  // Private DNS zone groups per RFC-71 rtype 'pdns'
  peKvDns: 'vd-pdns-kv-${purpose}-${nano16(seedPrefix, 'pdnskv')}'
  peStBlobDns: 'vd-pdns-st-blob-${purpose}-${nano16(seedPrefix, 'pdnsstblob')}'
  peStQueueDns: 'vd-pdns-st-queue-${purpose}-${nano16(seedPrefix, 'pdnsstqueue')}'
  peStTableDns: 'vd-pdns-st-table-${purpose}-${nano16(seedPrefix, 'pdnssttable')}'
  peAcrDns: 'vd-pdns-acr-${purpose}-${nano16(seedPrefix, 'pdnsacr')}'
  peAppApiDns: 'vd-pdns-app-api-${purpose}-${nano16(seedPrefix, 'pdnsappapi')}'
  peAppUiDns: 'vd-pdns-app-ui-${purpose}-${nano16(seedPrefix, 'pdnsappui')}'
  peFuncDns: 'vd-pdns-func-${purpose}-${nano16(seedPrefix, 'pdnsfunc')}'
  peSearchDns: 'vd-pdns-search-${purpose}-${nano16(seedPrefix, 'pdnssearch')}'
  peAiDns: 'vd-pdns-ai-${purpose}-${nano16(seedPrefix, 'pdnsai')}'
  peAutomationDns: 'vd-pdns-aa-${purpose}-${nano16(seedPrefix, 'pdnsaa')}'
  // Diagnostic settings per RFC-71
  diagKv: 'vd-diag-kv-${nano16(seedPrefix, 'diagkv')}'
  diagSt: 'vd-diag-st-${nano16(seedPrefix, 'diagst')}'
  diagAcr: 'vd-diag-acr-${nano16(seedPrefix, 'diagacr')}'
  diagAppApi: 'vd-diag-app-api-${nano16(seedPrefix, 'diagappapi')}'
  diagAppUi: 'vd-diag-app-ui-${nano16(seedPrefix, 'diagappui')}'
  diagFunc: 'vd-diag-func-${nano16(seedPrefix, 'diagfunc')}'
  diagAgw: 'vd-diag-agw-${nano16(seedPrefix, 'diagagw')}'
  diagPsql: 'vd-diag-psql-${nano16(seedPrefix, 'diagpsql')}'
  diagSearch: 'vd-diag-search-${nano16(seedPrefix, 'diagsearch')}'
  diagAi: 'vd-diag-ai-${nano16(seedPrefix, 'diagai')}'
  diagAutomation: 'vd-diag-aa-${nano16(seedPrefix, 'diagaa')}'
  diagLogic: 'vd-diag-logic-${nano16(seedPrefix, 'diaglogic')}'
}

output names object = names
