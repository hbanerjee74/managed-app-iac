#!/bin/bash
# SSH via Azure Bastion utility script
# Usage: ./scripts/ssh-via-bastion.sh [OPTIONS]

set -euo pipefail

# Default values
RESOURCE_GROUP="${RESOURCE_GROUP:-}"
VM_NAME="${VM_NAME:-}"
BASTION_NAME="${BASTION_NAME:-}"
USERNAME="${USERNAME:-azureuser}"
PORT="${PORT:-22}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

SSH into a VM via Azure Bastion.

Options:
  -g, --resource-group    Resource group name (required)
  -v, --vm-name          VM name (required)
  -b, --bastion-name     Bastion host name (required)
  -u, --username         SSH username (default: azureuser)
  -p, --port             SSH port (default: 22)
  -h, --help             Show this help message

Environment variables:
  RESOURCE_GROUP         Resource group name
  VM_NAME                VM name
  BASTION_NAME           Bastion host name
  USERNAME               SSH username
  PORT                   SSH port

Examples:
  $0 -g my-rg -v my-vm -b my-bastion
  RESOURCE_GROUP=my-rg VM_NAME=my-vm BASTION_NAME=my-bastion $0
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    -v|--vm-name)
      VM_NAME="$2"
      shift 2
      ;;
    -b|--bastion-name)
      BASTION_NAME="$2"
      shift 2
      ;;
    -u|--username)
      USERNAME="$2"
      shift 2
      ;;
    -p|--port)
      PORT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option: $1${NC}" >&2
      usage
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" ]]; then
  echo -e "${RED}Error: Resource group name is required${NC}" >&2
  usage
  exit 1
fi

if [[ -z "$VM_NAME" ]]; then
  echo -e "${RED}Error: VM name is required${NC}" >&2
  usage
  exit 1
fi

if [[ -z "$BASTION_NAME" ]]; then
  echo -e "${RED}Error: Bastion name is required${NC}" >&2
  usage
  exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
  echo -e "${RED}Error: Azure CLI is not installed${NC}" >&2
  exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
  echo -e "${YELLOW}Warning: Not logged in to Azure. Attempting to login...${NC}"
  az login
fi

# Verify VM exists
echo -e "${GREEN}Verifying VM exists...${NC}"
if ! az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &> /dev/null; then
  echo -e "${RED}Error: VM '$VM_NAME' not found in resource group '$RESOURCE_GROUP'${NC}" >&2
  exit 1
fi

# Check VM power state
VM_STATE=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --show-details --query "powerState" -o tsv)
if [[ "$VM_STATE" != "VM running" ]]; then
  echo -e "${YELLOW}Warning: VM is not running (current state: $VM_STATE)${NC}"
  read -p "Do you want to start the VM? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Starting VM...${NC}"
    az vm start --resource-group "$RESOURCE_GROUP" --name "$VM_NAME"
    echo -e "${GREEN}Waiting for VM to be ready...${NC}"
    sleep 10
  else
    echo -e "${RED}Aborting: VM must be running to connect${NC}" >&2
    exit 1
  fi
fi

# Verify Bastion exists
echo -e "${GREEN}Verifying Bastion exists...${NC}"
if ! az network bastion show --resource-group "$RESOURCE_GROUP" --name "$BASTION_NAME" &> /dev/null; then
  echo -e "${RED}Error: Bastion '$BASTION_NAME' not found in resource group '$RESOURCE_GROUP'${NC}" >&2
  exit 1
fi

# Get VM private IP address
echo -e "${GREEN}Retrieving VM private IP address...${NC}"
VM_PRIVATE_IP=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --show-details --query "privateIps" -o tsv | head -n 1)

if [[ -z "$VM_PRIVATE_IP" ]]; then
  echo -e "${RED}Error: Could not retrieve VM private IP address${NC}" >&2
  exit 1
fi

echo -e "${GREEN}VM private IP: $VM_PRIVATE_IP${NC}"

# Connect via Bastion
echo -e "${GREEN}Connecting to VM via Azure Bastion...${NC}"
echo -e "${YELLOW}Note: You will be prompted for the VM password${NC}"
echo ""

az network bastion ssh \
  --name "$BASTION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --target-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$VM_NAME" \
  --auth-type password \
  --username "$USERNAME"
