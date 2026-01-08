targetScope = 'resourceGroup'

@description('Resource group name used as seed for deterministic nanoid generation.')
param resourceGroupName string

// helper to build deterministic nanoids per resource type
param seedPrefix string = resourceGroupName

func nano16(seed string, suffix string) string => toLower('${substring(uniqueString('${seed}-${suffix}-a'), 0, 8)}${substring(uniqueString('${seed}-${suffix}-b'), 0, 8)}')
func nano8(seed string, suffix string) string => toLower(substring(uniqueString('${seed}-${suffix}'), 0, 8))

var names = {
  uami: 'vd-uami-${nano16(seedPrefix, 'uami')}'
  vnet: 'vd-vnet-${nano16(seedPrefix, 'vnet')}'
  nsgAppgw: 'vd-nsg-appgw-${nano16(seedPrefix, 'nsgappgw')}'
  nsgAks: 'vd-nsg-aks-${nano16(seedPrefix, 'nsgaks')}'
  nsgAppsvc: 'vd-nsg-appsvc-${nano16(seedPrefix, 'nsgappsvc')}'
  nsgPe: 'vd-nsg-pe-${nano16(seedPrefix, 'nsgpe')}'
  kv: 'vd-kv-${nano16(seedPrefix, 'kv')}'
  storage: 'vdst${nano8(seedPrefix, 'st')}'
  acr: 'vdacr${nano8(seedPrefix, 'acr')}'
  law: 'vd-law-${nano16(seedPrefix, 'law')}'
  asp: 'vd-asp-${nano16(seedPrefix, 'asp')}'
  agw: 'vd-agw-${nano16(seedPrefix, 'agw')}'
  pipAgw: 'vd-pip-agw-${nano16(seedPrefix, 'pipagw')}'
  psql: 'vd-psql-${nano16(seedPrefix, 'psql')}'
  search: 'vd-search-${nano16(seedPrefix, 'search')}'
  ai: 'vd-ai-${nano16(seedPrefix, 'ai')}'
  automation: 'vd-aa-${nano16(seedPrefix, 'aa')}'
  vm: 'vd-vm-${nano16(seedPrefix, 'vm')}'
  bastion: 'vd-bastion-${nano16(seedPrefix, 'bastion')}'
  pipBastion: 'vd-pip-bastion-${nano16(seedPrefix, 'pipbastion')}'
  // Private endpoints per RFC-71 rtype 'pe'
  peKv: 'vd-pe-kv-${nano16(seedPrefix, 'pekv')}'
  peStBlob: 'vd-pe-st-blob-${nano16(seedPrefix, 'pestblob')}'
  peStQueue: 'vd-pe-st-queue-${nano16(seedPrefix, 'pestqueue')}'
  peStTable: 'vd-pe-st-table-${nano16(seedPrefix, 'pesttable')}'
  peAcr: 'vd-pe-acr-${nano16(seedPrefix, 'peacr')}'
  peSearch: 'vd-pe-search-${nano16(seedPrefix, 'pesearch')}'
  peAi: 'vd-pe-ai-${nano16(seedPrefix, 'peai')}'
  peAutomation: 'vd-pe-aa-${nano16(seedPrefix, 'peaa')}'
  // Private DNS zone groups per RFC-71 rtype 'pdns'
  peKvDns: 'vd-pdns-kv-${nano16(seedPrefix, 'pdnskv')}'
  peStBlobDns: 'vd-pdns-st-blob-${nano16(seedPrefix, 'pdnsstblob')}'
  peStQueueDns: 'vd-pdns-st-queue-${nano16(seedPrefix, 'pdnsstqueue')}'
  peStTableDns: 'vd-pdns-st-table-${nano16(seedPrefix, 'pdnssttable')}'
  peAcrDns: 'vd-pdns-acr-${nano16(seedPrefix, 'pdnsacr')}'
  peSearchDns: 'vd-pdns-search-${nano16(seedPrefix, 'pdnssearch')}'
  peAiDns: 'vd-pdns-ai-${nano16(seedPrefix, 'pdnsai')}'
  peAutomationDns: 'vd-pdns-aa-${nano16(seedPrefix, 'pdnsaa')}'
  // Diagnostic settings per RFC-71
  diagKv: 'vd-diag-kv-${nano16(seedPrefix, 'diagkv')}'
  diagSt: 'vd-diag-st-${nano16(seedPrefix, 'diagst')}'
  diagAcr: 'vd-diag-acr-${nano16(seedPrefix, 'diagacr')}'
  diagAgw: 'vd-diag-agw-${nano16(seedPrefix, 'diagagw')}'
  diagPsql: 'vd-diag-psql-${nano16(seedPrefix, 'diagpsql')}'
  diagSearch: 'vd-diag-search-${nano16(seedPrefix, 'diagsearch')}'
  diagAi: 'vd-diag-ai-${nano16(seedPrefix, 'diagai')}'
  diagAutomation: 'vd-diag-aa-${nano16(seedPrefix, 'diagaa')}'
}

output names object = names
