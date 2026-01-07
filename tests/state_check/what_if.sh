#!/usr/bin/env bash
set -euo pipefail

# Runs az what-if against the resource group-scope deployment and stores the JSON result.
# Usage: ./tests/state_check/what_if.sh [params_file]
# Defaults: params_file=tests/fixtures/params.dev.json
# Extracts resourceGroupName from params file

PARAMS_FILE="${1:-tests/fixtures/params.dev.json}"
OUT_FILE="tests/state_check/what-if.json"

# Extract resourceGroupName from params file (metadata or parameters)
RG_NAME=$(jq -r 'if .metadata.resourceGroupName then .metadata.resourceGroupName else .parameters.resourceGroupName.value end' "$PARAMS_FILE")

if [ -z "$RG_NAME" ] || [ "$RG_NAME" == "null" ]; then
  echo "Error: Could not extract resourceGroupName from $PARAMS_FILE"
  exit 1
fi

echo "Running what-if for iac/main.bicep in resource group $RG_NAME using $PARAMS_FILE"
az deployment group what-if \
  --resource-group "$RG_NAME" \
  -f iac/main.bicep \
  -p "@${PARAMS_FILE}" \
  --output json \
  --result-format=FullResourcePayloads \
  --no-pretty-print \
  > "$OUT_FILE"

echo "What-if result saved to $OUT_FILE"
