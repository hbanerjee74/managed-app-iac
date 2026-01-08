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
  modules/            # Domain modules (identity, network, kv, storage, acr, data, compute, gateway, search, cognitive-services, automation, diagnostics)
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
   # E2E actual deployment test (creates real resources, opt-in)
   ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
   ```

   **Warning**: This creates real Azure resources and incurs costs. The test automatically creates the resource group before deployment and deletes it after (even on failure).

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
# Deploy and validate (auto-creates/deletes resource group)
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment

# Keep resource group for debugging/inspection
ENABLE_ACTUAL_DEPLOYMENT=true KEEP_RESOURCE_GROUP=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

**Warning**: Actual deployment tests create real Azure resources and incur costs. Resource groups are automatically created before each test and deleted after (unless `KEEP_RESOURCE_GROUP=true` is set).

For comprehensive testing documentation, see [`tests/README.md`](tests/README.md).

## Documentation

- **Testing**: See [`tests/README.md`](tests/README.md) for comprehensive test documentation
- **Repository Guidelines**: See [`AGENTS.md`](AGENTS.md) for development practices and standards
- **Release Notes**: See `docs/RELEASE-NOTES-*.md` for version history

## Release Notes

- 2026-01-08 — v0.7.0 Module refactoring: Split security module into kv, storage, and acr modules: [docs/RELEASE-NOTES-2026-01-08-v0.7.0.md](docs/RELEASE-NOTES-2026-01-08-v0.7.0.md)
- 2026-01-08 — v0.6.0 Test harness improvements and documentation consolidation: [docs/RELEASE-NOTES-2026-01-08-v0.6.0.md](docs/RELEASE-NOTES-2026-01-08-v0.6.0.md)
- 2026-01-05 — v0.5.0 RFC-71 deterministic naming: [docs/RELEASE-NOTES-2026-01-05-v0.5.0.md](docs/RELEASE-NOTES-2026-01-05-v0.5.0.md)
- 2026-01-03 — v0.4.0 module validator + RFC-64 params: [docs/RELEASE-NOTES-2026-01-03-v0.4.0.md](docs/RELEASE-NOTES-2026-01-03-v0.4.0.md)
- 2026-01-03 — v0.3.0 validator resource-level coverage: [docs/RELEASE-NOTES-2026-01-03-v0.3.0.md](docs/RELEASE-NOTES-2026-01-03-v0.3.0.md)
- 2026-01-03 — v0.2.0 dev/test strict enforcement: [docs/RELEASE-NOTES-2026-01-03-v0.2.0.md](docs/RELEASE-NOTES-2026-01-03-v0.2.0.md)
- 2026-01-03 — v0.1.0 baseline: [docs/RELEASE-NOTES-2026-01-03.md](docs/RELEASE-NOTES-2026-01-03.md)
