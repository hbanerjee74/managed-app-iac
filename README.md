# Managed Application IaC for PRD-30

This repository contains the Bicep-based infrastructure for PRD-30 (managed application), aligned to RFC-42, RFC-64, and RFC-71. The modules include resource-level validation tooling for marketplace deployment.

## Prerequisites

- **Azure CLI** installed and configured (`az login`)
- **Python 3.x** with pytest installed
- **Azure subscription** with appropriate permissions
- **Bicep CLI** (included with Azure CLI)

## Project Structure

```text
iac/
  main.bicep          # Resource group-scope entrypoint for managed application deployment
  modules/            # Domain modules (identity, network, kv, storage, acr, psql, compute, gateway, search, cognitive-services, automation, diagnostics)
  lib/                # Shared helpers (naming per RFC-71, constants)
tests/
  fixtures/
    params.dev.json   # Sample parameters for local testing
  unit/               # Unit tests for individual modules
  e2e/                # End-to-end tests for main.bicep
```

## Quick Start

1. **Authenticate with Azure CLI:**

   ```bash
   az login
   ```

2. **Configure parameters:**

   Edit `tests/fixtures/params.dev.json` with your subscription and resource group details:

   ```json
   {
     "metadata": {
       "subscriptionId": "your-subscription-id",
       "resourceGroupName": "your-rg-name",
       "location": "eastus"
     },
     "parameters": {
       ...
     }
   }
   ```

3. **Run what-if tests (dry run, recommended first):**

   ```bash
   # Unit tests automatically create resource group if needed
   pytest tests/unit/test_modules.py -v

   # E2E what-if tests (safe, no actual deployment)
   pytest tests/e2e/
   ```

   The tests validate your Bicep templates and show what would be deployed without creating resources.

4. **Deploy (if tests pass and what-if looks good):**

   ```bash
   # E2E actual deployment test (creates/updates real resources, opt-in)
   ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
   ```

   **Warning**: This creates/updates real Azure resources and incurs costs. The test automatically creates the resource group if it doesn't exist, or reuses it if it does. Resource group persists between test runs - subsequent runs will update existing resources.

## Parameters

See `tests/fixtures/params.dev.json` for all available parameters. Key parameters:

**Required:**

- `resourceGroupName` (replaces `resourceGroup` and `mrgName`)
- `location`
- `contactEmail`
- `adminObjectId`
- `adminPrincipalType`

**Network:**

- `customerIpRanges` - IP ranges for WAF allowlist
- `publisherIpRanges` - IP ranges for WAF allowlist
- **Note:** VNet and subnet CIDRs are hardcoded in `network.bicep` (VNet: `10.20.0.0/16`, subnets: `/24`). The `servicesVnetCidr` parameter has been removed to simplify deployment and avoid Azure `cidrSubnet` limitations.

**Compute:**

- `sku` - App Service Plan SKU
- `computeTier` - PostgreSQL compute tier
- `aiServicesTier` - AI services tier

**Optional (with defaults):**

- `appGwSku` - Application Gateway SKU (default: WAF_v2)
- `appGwCapacity` - Application Gateway capacity (default: 1)
- `storageGB` - PostgreSQL storage in GB
- `backupRetentionDays` - PostgreSQL backup retention
- `retentionDays` - Log Analytics retention

For full parameter documentation, see RFC-64.

## Testing

### Unit Tests

```bash
pytest tests/unit/test_modules.py -v
```

**Note**: Unit tests automatically create the resource group if it doesn't exist (using RG name and location from `tests/fixtures/params.dev.json`).

### E2E Tests (What-if mode, safe)

```bash
# Unit tests automatically create resource group if needed
pytest tests/e2e/
```

### E2E Tests (Actual deployment, opt-in)

```bash
# Deploy and validate (creates RG if needed, or updates existing resources)
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

**Warning**: Actual deployment tests create/update real Azure resources and incur costs. The resource group is created if it doesn't exist, or reused if it does. Resource group persists between test runs - subsequent runs will update existing resources instead of deleting and recreating them.

For comprehensive testing documentation, see [`tests/README.md`](tests/README.md).

## Troubleshooting: SSH via Azure Bastion

The infrastructure includes a VM jump host and Azure Bastion for secure remote access to troubleshoot resources within the VNet. The VM is created in a stopped (deallocated) state by default to minimize costs.

### Prerequisites

- Azure CLI installed and configured (`az login`)
- VM and Bastion resources deployed (part of main deployment)
- VM must be started before connecting

### Connecting to the Jump Host

Use the provided SSH utility script to connect to the VM via Azure Bastion:

```bash
./scripts/ssh-via-bastion.sh \
  --resource-group <your-resource-group> \
  --vm-name <vm-name> \
  --bastion-name <bastion-name> \
  --username azureuser
```

**Example:**

```bash
# Using command-line arguments
./scripts/ssh-via-bastion.sh \
  -g test-rg-sg \
  -v vd-vm-xxxxxxxx \
  -b vd-bastion-xxxxxxxx \
  -u azureuser

# Using environment variables
export RESOURCE_GROUP=test-rg-sg
export VM_NAME=vd-vm-xxxxxxxx
export BASTION_NAME=vd-bastion-xxxxxxxx
./scripts/ssh-via-bastion.sh
```

### Script Features

The SSH utility script (`scripts/ssh-via-bastion.sh`) provides:

- **Automatic VM state checking**: Verifies if the VM is running
- **VM startup prompt**: Offers to start the VM if it's stopped
- **Resource validation**: Verifies VM and Bastion exist before connecting
- **Private IP resolution**: Automatically retrieves the VM's private IP address
- **Secure connection**: Uses Azure Bastion for password-based SSH authentication

### Manual VM Management

You can also manage the VM state manually using Azure CLI:

```bash
# Start the VM
az vm start --resource-group <resource-group> --name <vm-name>

# Stop the VM (deallocates to save costs)
az vm deallocate --resource-group <resource-group> --name <vm-name>

# Check VM status
az vm show --resource-group <resource-group> --name <vm-name> --show-details --query "powerState" -o tsv
```

### Getting Resource Names

After deployment, you can retrieve the VM and Bastion names from the deployment outputs:

```bash
# Get VM name
az deployment group show \
  --resource-group <resource-group> \
  --name <deployment-name> \
  --query "properties.outputs.vmName.value" -o tsv

# Get Bastion name
az deployment group show \
  --resource-group <resource-group> \
  --name <deployment-name> \
  --query "properties.outputs.bastionName.value" -o tsv
```

Or check the resource group directly:

```bash
# List VMs
az vm list --resource-group <resource-group> --query "[].name" -o tsv

# List Bastion hosts
az network bastion list --resource-group <resource-group> --query "[].name" -o tsv
```

### SSH Script Usage

```bash
Usage: ./scripts/ssh-via-bastion.sh [OPTIONS]

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
```

## Documentation

- **Testing**: See [`tests/README.md`](tests/README.md) for comprehensive test documentation
- **Repository Guidelines**: See [`AGENTS.md`](AGENTS.md) for development practices and standards
- **Release Notes**: See `docs/RELEASE-NOTES-*.md` for version history

## Release Notes

- 2026-01-08 — v0.7.1 Troubleshooting infrastructure and customer admin data plane access: [docs/RELEASE-NOTES-2026-01-08-v0.7.1.md](docs/RELEASE-NOTES-2026-01-08-v0.7.1.md)
- 2026-01-08 — v0.7.0 Module refactoring: Split security module into kv, storage, and acr modules: [docs/RELEASE-NOTES-2026-01-08-v0.7.0.md](docs/RELEASE-NOTES-2026-01-08-v0.7.0.md)
- 2026-01-08 — v0.6.0 Test harness improvements and documentation consolidation: [docs/RELEASE-NOTES-2026-01-08-v0.6.0.md](docs/RELEASE-NOTES-2026-01-08-v0.6.0.md)
- 2026-01-05 — v0.5.0 RFC-71 deterministic naming: [docs/RELEASE-NOTES-2026-01-05-v0.5.0.md](docs/RELEASE-NOTES-2026-01-05-v0.5.0.md)
- 2026-01-03 — v0.4.0 module validator + RFC-64 params: [docs/RELEASE-NOTES-2026-01-03-v0.4.0.md](docs/RELEASE-NOTES-2026-01-03-v0.4.0.md)
- 2026-01-03 — v0.3.0 validator resource-level coverage: [docs/RELEASE-NOTES-2026-01-03-v0.3.0.md](docs/RELEASE-NOTES-2026-01-03-v0.3.0.md)
- 2026-01-03 — v0.2.0 dev/test strict enforcement: [docs/RELEASE-NOTES-2026-01-03-v0.2.0.md](docs/RELEASE-NOTES-2026-01-03-v0.2.0.md)
- 2026-01-03 — v0.1.0 baseline: [docs/RELEASE-NOTES-2026-01-03.md](docs/RELEASE-NOTES-2026-01-03.md)
