#!/bin/bash
# Script to test network module with actual deployment (not what-if)
# Usage: ./tests/scripts/test-network-actual.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/tests/unit/fixtures"
PARAMS_FILE="$PROJECT_ROOT/tests/fixtures/params.dev.json"
BICEP_FILE="$FIXTURES_DIR/test-network.bicep"

# Extract resource group name and location from params.dev.json
RG_NAME=$(jq -r '.metadata.resourceGroupName' "$PARAMS_FILE")
LOCATION=$(jq -r '.metadata.location' "$PARAMS_FILE")

echo "Testing network module with actual deployment..."
echo "Resource Group: $RG_NAME"
echo "Location: $LOCATION"
echo "Bicep File: $BICEP_FILE"
echo "Note: VNet and subnet CIDRs are hardcoded in network.bicep"
echo ""

# Ensure resource group exists
echo "Ensuring resource group exists..."
az group create --name "$RG_NAME" --location "$LOCATION" 2>/dev/null || true

# Deploy the network module with only the required parameters
echo "Deploying network module..."
az deployment group create \
  --resource-group "$RG_NAME" \
  --template-file "$BICEP_FILE" \
  --parameters \
    resourceGroupName="$RG_NAME" \
    location="$LOCATION" \
  --output json

echo ""
echo "Deployment completed successfully!"
