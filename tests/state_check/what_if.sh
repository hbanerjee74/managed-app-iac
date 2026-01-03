#!/usr/bin/env bash
set -euo pipefail

# Runs az what-if against the subscription-scope deployment and stores the JSON result.
# Usage: ./tests/state_check/what_if.sh <location> [params_file]
# Defaults: location=eastus, params_file=iac/params.dev.json

LOCATION="${1:-eastus}"
PARAMS_FILE="${2:-iac/params.dev.json}"
OUT_FILE="tests/state_check/what-if.json"

echo "Running what-if for iac/main.bicep in $LOCATION using $PARAMS_FILE"
az deployment sub what-if \
  -f iac/main.bicep \
  -l "$LOCATION" \
  -p "@${PARAMS_FILE}" \
  --result-format=Full \
  --no-pretty-print \
  > "$OUT_FILE"

echo "What-if result saved to $OUT_FILE"
