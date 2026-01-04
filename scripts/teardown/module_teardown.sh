#!/usr/bin/env bash
set -euo pipefail

# Tear down resources for a specific module in a resource group.
# Usage: ./scripts/teardown/module_teardown.sh <resource_group> <module> [--dry-run]
# Modules: diagnostics|identity|network|security|data|compute|automation|ai|gateway

RG="${1:?resource group required}"
MODULE="${2:?module required}"
DRY_RUN="false"

if [[ ${3:-} == "--dry-run" ]]; then
  DRY_RUN="true"
fi

case "$MODULE" in
  diagnostics)
    TYPES=(
      "Microsoft.OperationalInsights/workspaces/tables"
      "Microsoft.OperationalInsights/workspaces"
    )
    ;;
  identity)
    TYPES=("Microsoft.ManagedIdentity/userAssignedIdentities")
    ;;
  network)
    TYPES=(
      "Microsoft.Network/networkSecurityGroups"
      "Microsoft.Network/virtualNetworks"
    )
    ;;
  security)
    TYPES=(
      "Microsoft.KeyVault/vaults"
      "Microsoft.Storage/storageAccounts"
      "Microsoft.ContainerRegistry/registries"
    )
    ;;
  data)
    TYPES=("Microsoft.DBforPostgreSQL/flexibleServers")
    ;;
  compute)
    TYPES=(
      "Microsoft.Web/sites"
      "Microsoft.Web/serverfarms"
    )
    ;;
  automation)
    TYPES=("Microsoft.Automation/automationAccounts")
    ;;
  ai)
    TYPES=(
      "Microsoft.Search/searchServices"
      "Microsoft.CognitiveServices/accounts"
    )
    ;;
  gateway)
    TYPES=(
      "Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies"
      "Microsoft.Network/applicationGateways"
      "Microsoft.Network/publicIPAddresses"
    )
    ;;
  *)
    echo "Unknown module: $MODULE" >&2
    exit 1
    ;;
esac

echo "Tearing down module '$MODULE' in RG '$RG'"
[[ "$DRY_RUN" == "true" ]] && echo "(dry run: no deletes will be issued)"

for TYPE in "${TYPES[@]}"; do
  IDS=$(az resource list -g "$RG" --resource-type "$TYPE" --query "[].id" -o tsv)
  if [ -z "$IDS" ]; then
    continue
  fi
  while read -r id; do
    [ -z "$id" ] && continue
    echo "Deleting $id"
    if [[ "$DRY_RUN" == "false" ]]; then
      az resource delete --ids "$id"
    fi
  done <<< "$IDS"
done

echo "Done."
