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
  modules/            # Domain modules (identity, network, kv, storage, acr, psql, compute, gateway, search, cognitive-services, automation, diagnostics, rbac)
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

   Edit `tests/fixtures/params.dev.json` with your subscription and resource group details.

3. **Run tests:**

   See [`tests/README.md`](tests/README.md) for comprehensive testing documentation.

4. **Deploy (if tests pass and what-if looks good):**

   ```bash
   # E2E actual deployment test (creates/updates real resources, opt-in)
   ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
   ```

   **Warning**: This creates/updates real Azure resources and incurs costs. The test automatically creates the resource group if it doesn't exist, or reuses it if it does. Resource group persists between test runs - subsequent runs will update existing resources.
   
   **Note**: Deployments use **Complete mode** to ensure resource group state matches the template exactly. Resources not defined in the template will be deleted.

## Parameters

See `tests/fixtures/params.dev.json` for all available parameters. Key parameters:

**Required:**

- `resourceGroupName` (replaces `resourceGroup` and `mrgName`)
- `location`
- `contactEmail`
- `customerAdminObjectId` - Customer admin Entra object ID
- `customerAdminPrincipalType` - Principal type for customer admin (User or Group, defaults to User)

**Network:**

- `customerIpRanges` - IP ranges for WAF allowlist
- `publisherIpRanges` - IP ranges for WAF allowlist
- **Note:** VNet and subnet CIDRs are hardcoded in `network.bicep` (VNet: `10.20.0.0/16`, subnets: `/24`). The `servicesVnetCidr` parameter has been removed to simplify deployment and avoid Azure `cidrSubnet` limitations.

**Compute:**

- `sku` - App Service Plan SKU (allowed: B1, B2, B3, S1, S2, S3, P1v3, P2v3, P3v3)
- `computeTier` - PostgreSQL compute tier (allowed: Standard_B1ms, Standard_B1s, Standard_B2ms, Standard_B2s, GP_Standard_D2s_v3, GP_Standard_D4s_v3)
- `aiServicesTier` - AI services tier (allowed: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2)
- `nodeSize` - AKS node size (allowed: Standard_D4s_v3, Standard_D8s_v3, Standard_D16s_v3) - Note: Currently unused as AKS deployment is out of scope

**Optional (with defaults):**

- `appGwSku` - Application Gateway SKU (default: WAF_v2, allowed: WAF_v2)
- `appGwCapacity` - Application Gateway capacity (default: 1, range: 1-10)
- `storageGB` - PostgreSQL storage in GB (default: 128, range: 32-16384)
- `backupRetentionDays` - PostgreSQL backup retention (default: 7, range: 7-35)
- `retentionDays` - Log Analytics retention (default: 30, range: 30-730)

**Managed Application (optional):**

- `publisherAdminObjectId` - Publisher admin Entra object ID (for managed applications only)
- `publisherAdminPrincipalType` - Principal type for publisher admin (User or Group, defaults to User)

For full parameter documentation, see RFC-64.

## `isManagedApplication` Parameter

The `isManagedApplication` parameter controls behavior differences between managed application deployments (cross-tenant) and same-tenant testing scenarios.

**Default**: `true` (managed application scenario)

**Usage:**

1. **RBAC Module** (`iac/modules/rbac.bicep`): Controls `delegatedManagedIdentityResourceId` property in role assignments and Publisher Admin runbook creation
   - `true`: Sets `delegatedManagedIdentityResourceId` to UAMI ID (required for cross-tenant managed apps) and creates Publisher Admin runbook
   - `false`: Sets `delegatedManagedIdentityResourceId` to `null` (same-tenant testing) and skips Publisher Admin runbook creation

2. **Main Template** (`iac/main.bicep`): Controls tag application logic
   - `false`: Uses `defaultTags` from metadata if individual tag params are empty
   - `true`: Always uses individual tag parameters (ignores `defaultTags`)

**Configuration:**

- **Managed Application** (Production): Set `isManagedApplication: true` in metadata
- **Same-Tenant Testing** (Development): Set `isManagedApplication: false` in metadata and provide `defaultTags`

## Testing

For comprehensive testing documentation, see [`tests/README.md`](tests/README.md).

## Updating RBAC After Deployment

RBAC role assignments are executed during deployment via PowerShell scripts and are also available as automation runbooks for on-demand updates. This allows you to re-apply RBAC assignments without redeploying the entire infrastructure.

### Available Runbooks

Three automation runbooks are created during deployment:

1. **`assign-rbac-roles-uami`** - Re-applies all RBAC roles for the User-Assigned Managed Identity (UAMI)
2. **`assign-rbac-roles-admin`** - Re-applies all RBAC roles for Customer Admin
3. **`assign-rbac-roles-publisher-admin`** - Re-applies all RBAC roles for Publisher Admin (managed applications only)

### Publishing Runbooks

Runbooks are created in draft state and must be published before they can be executed. Publish runbooks via Azure Portal or Azure CLI:

**Via Azure CLI:**

```bash
# Publish UAMI runbook
az automation runbook publish \
  --automation-account-name <automation-account-name> \
  --resource-group <resource-group> \
  --name assign-rbac-roles-uami

# Publish Customer Admin runbook
az automation runbook publish \
  --automation-account-name <automation-account-name> \
  --resource-group <resource-group> \
  --name assign-rbac-roles-admin

# Publish Publisher Admin runbook (managed applications only)
az automation runbook publish \
  --automation-account-name <automation-account-name> \
  --resource-group <resource-group> \
  --name assign-rbac-roles-publisher-admin
```

**Via Azure Portal:**

1. Navigate to your Automation Account in the Azure Portal
2. Go to **Runbooks** under **Process Automation**
3. Find the runbook (e.g., `assign-rbac-roles-uami`)
4. Click **Edit** → **Publish** → **Yes**

### Executing Runbooks

Once published, runbooks can be executed on-demand to re-apply RBAC assignments:

**Via Azure CLI:**

```bash
# Execute UAMI runbook
az automation runbook start \
  --automation-account-name <automation-account-name> \
  --resource-group <resource-group> \
  --name assign-rbac-roles-uami

# Execute Customer Admin runbook
az automation runbook start \
  --automation-account-name <automation-account-name> \
  --resource-group <resource-group> \
  --name assign-rbac-roles-admin

# Execute Publisher Admin runbook (managed applications only)
az automation runbook start \
  --automation-account-name <automation-account-name> \
  --resource-group <resource-group> \
  --name assign-rbac-roles-publisher-admin
```

**Via Azure Portal:**

1. Navigate to your Automation Account → **Runbooks**
2. Select the runbook you want to execute
3. Click **Start** → **OK**

### Runbook Parameters

Runbooks accept parameters when executed. The scripts use parameter defaults from environment variables (set during deployment), but parameters can also be passed explicitly when starting runbooks.

**Required parameters for each runbook:**

**`assign-rbac-roles-uami`:**
- `ResourceGroupId` - Resource group resource ID
- `UamiPrincipalId` - UAMI principal ID
- `UamiId` - UAMI resource ID
- `LawId` - Log Analytics Workspace resource ID
- `LawName` - Log Analytics Workspace name
- `KvId` - Key Vault resource ID
- `StorageId` - Storage Account resource ID
- `AcrId` - Container Registry resource ID
- `SearchId` - Azure AI Search resource ID
- `AiId` - Cognitive Services resource ID
- `AutomationId` - Automation Account resource ID
- `IsManagedApplication` - Boolean flag (true/false)

**`assign-rbac-roles-admin` (Customer Admin):**
- `ResourceGroupId` - Resource group resource ID
- `CustomerAdminObjectId` - Customer admin Entra object ID
- `CustomerAdminPrincipalType` - Principal type (User or Group)
- `KvId` - Key Vault resource ID
- `StorageId` - Storage Account resource ID
- `AcrId` - Container Registry resource ID
- `SearchId` - Azure AI Search resource ID
- `AiId` - Cognitive Services resource ID
- `AutomationId` - Automation Account resource ID

**`assign-rbac-roles-publisher-admin` (Publisher Admin):**
- Same parameters as Customer Admin runbook, but with `PublisherAdminObjectId` and `PublisherAdminPrincipalType`

**Note**: When runbooks are executed via Azure Portal, you can pass these parameters in the **Start Runbook** dialog. When executed via Azure CLI, use the `--parameters` flag:

```bash
az automation runbook start \
  --automation-account-name <automation-account-name> \
  --resource-group <resource-group> \
  --name assign-rbac-roles-uami \
  --parameters ResourceGroupId=<rg-id> UamiPrincipalId=<uami-principal-id> ...
```

### When to Use Runbooks

Use automation runbooks to update RBAC assignments when:

- **RBAC assignments were accidentally removed**: Re-apply roles without redeploying
- **New resources were added**: Update RBAC to include new resources
- **Role definitions changed**: Re-apply updated role assignments
- **Troubleshooting**: Verify RBAC assignments are correct

**Note**: Runbooks are idempotent - they can be executed multiple times safely. The scripts use deterministic GUID generation to ensure role assignments are consistent.

### Troubleshooting

**Runbook not found:**
- Verify the Automation Account name and resource group are correct
- Check that the runbook was created during deployment (check deployment outputs)

**Runbook execution fails:**
- Check Automation Account job history for error details
- Verify the Automation Account has the required permissions (uses UAMI identity)
- Ensure all required resources exist in the resource group

**RBAC assignments not applied:**
- Check runbook execution logs in Automation Account → **Jobs**
- Verify the UAMI has sufficient permissions to create role assignments
- Check Azure Activity Log for role assignment creation events

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

- 2026-01-08 — v0.7.2 RBAC refactoring: PowerShell scripts and automation runbooks: [docs/RELEASE-NOTES-2026-01-08-v0.7.2.md](docs/RELEASE-NOTES-2026-01-08-v0.7.2.md)
- 2026-01-08 — v0.7.1 Troubleshooting infrastructure and customer admin data plane access: [docs/RELEASE-NOTES-2026-01-08-v0.7.1.md](docs/RELEASE-NOTES-2026-01-08-v0.7.1.md)
- 2026-01-08 — v0.7.0 Module refactoring: Split security module into kv, storage, and acr modules: [docs/RELEASE-NOTES-2026-01-08-v0.7.0.md](docs/RELEASE-NOTES-2026-01-08-v0.7.0.md)
- 2026-01-08 — v0.6.0 Test harness improvements and documentation consolidation: [docs/RELEASE-NOTES-2026-01-08-v0.6.0.md](docs/RELEASE-NOTES-2026-01-08-v0.6.0.md)
- 2026-01-05 — v0.5.0 RFC-71 deterministic naming: [docs/RELEASE-NOTES-2026-01-05-v0.5.0.md](docs/RELEASE-NOTES-2026-01-05-v0.5.0.md)
- 2026-01-03 — v0.4.0 module validator + RFC-64 params: [docs/RELEASE-NOTES-2026-01-03-v0.4.0.md](docs/RELEASE-NOTES-2026-01-03-v0.4.0.md)
- 2026-01-03 — v0.3.0 validator resource-level coverage: [docs/RELEASE-NOTES-2026-01-03-v0.3.0.md](docs/RELEASE-NOTES-2026-01-03-v0.3.0.md)
- 2026-01-03 — v0.2.0 dev/test strict enforcement: [docs/RELEASE-NOTES-2026-01-03-v0.2.0.md](docs/RELEASE-NOTES-2026-01-03-v0.2.0.md)
- 2026-01-03 — v0.1.0 baseline: [docs/RELEASE-NOTES-2026-01-03-v0.1.0.md](docs/RELEASE-NOTES-2026-01-03-v0.1.0.md)
