# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Bicep-based Infrastructure as Code (IaC) for PRD-30, implementing a managed application infrastructure for the VibeData platform. The project deploys a complete Azure resource group with networking, security, compute, storage, and monitoring components aligned to RFCs 42, 64, and 71.

## Essential Commands

### Testing and Validation

```bash
# Authenticate with Azure (required for most tests)
az login

# Run all unit tests (validates individual modules, auto-creates RG if needed)
pytest tests/unit/test_modules.py -v

# Run specific module tests
pytest tests/unit/test_modules.py -v -k "network"

# Run only compilation tests (no Azure CLI required)
pytest tests/unit/test_modules.py -v -k "compiles"

# Run E2E what-if tests (safe, no actual deployment)
pytest tests/e2e/

# Run actual deployment (opt-in, creates real resources)
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment

# Validate required parameters are present
pytest tests/test_params.py

# Run a single test with verbose output
pytest tests/unit/test_modules.py::TestBicepModules::test_what_if_succeeds[network-test-network.bicep] -vv
```

### Bicep Operations

```bash
# Compile main template
az bicep build --file iac/main.bicep

# Manual what-if validation
az deployment group what-if --resource-group <rg-name> -f iac/main.bicep -p @tests/fixtures/params.dev.json

# Manual deployment (Complete mode - deletes resources not in template)
az deployment group create --mode Complete --resource-group <rg-name> -f iac/main.bicep -p @tests/fixtures/params.dev.json
```

### RBAC and Runbook Management

```bash
# Create runbook in Automation Account
az automation runbook create \
  --automation-account-name <aa-name> \
  --resource-group <rg-name> \
  --name assign-rbac-roles-uami \
  --type PowerShell

# Upload runbook content
az automation runbook replace-content \
  --automation-account-name <aa-name> \
  --resource-group <rg-name> \
  --name assign-rbac-roles-uami \
  --content-path scripts/assign-rbac-roles-uami.ps1

# Publish runbook
az automation runbook publish \
  --automation-account-name <aa-name> \
  --resource-group <rg-name> \
  --name assign-rbac-roles-uami

# Execute runbook (required after deployment for RBAC)
az automation runbook start \
  --automation-account-name <aa-name> \
  --resource-group <rg-name> \
  --name assign-rbac-roles-uami
```

### Troubleshooting and Cleanup

```bash
# SSH to jump host via Azure Bastion
./scripts/ssh-via-bastion.sh -g <rg-name> -v <vm-name> -b <bastion-name> -u azureuser

# Hard delete Log Analytics Workspace (required before RG deletion)
az monitor log-analytics workspace delete --force \
  --resource-group <rg-name> \
  --workspace-name <workspace-name>

# Purge soft-deleted Cognitive Services account
az cognitiveservices account purge \
  --location <location> \
  --name <account-name> \
  --resource-group <rg-name>

# Find available VM SKUs in a region
az vm list-skus --location <location> --size Standard_D --all --output table
```

## Architecture and Structure

### High-Level Architecture

The infrastructure follows a **single-tenant deployment model** where all resources are provisioned in a single resource group. Key architectural patterns:

1. **Deterministic Naming** (RFC-71): All resource names use per-resource 16-char nanoids derived from the resource group name via `iac/lib/naming.bicep`. Storage resources use 8-char nanoids due to Azure constraints.

2. **Private Networking** (RFC-42): All PaaS resources (Key Vault, Storage, ACR, PostgreSQL, AI Search, Cognitive Services) are deployed with public access disabled and accessed exclusively via private endpoints in the `subnet-pe` subnet.

3. **Network Topology**: Hardcoded VNet CIDR (10.20.0.0/16) with five /24 subnets:
   - 10.20.0.0/24: Application Gateway
   - 10.20.1.0/24: AKS (reserved, not currently deployed)
   - 10.20.2.0/24: App Service VNet integration
   - 10.20.3.0/24: Private endpoints
   - 10.20.4.0/24: Azure Bastion

4. **Security Model**:
   - User-Assigned Managed Identity (UAMI) with Resource Group Contributor and resource-scoped roles
   - Application Gateway with WAF_v2 and customer IP allowlist
   - All traffic through private endpoints with private DNS zones
   - Automation Account runbooks for RBAC management

5. **Observability**: All resources emit diagnostics to a central Log Analytics Workspace with custom table `VibeData_Operations_CL`.

### Module Organization

The repository follows a **module-per-domain** pattern:

- `iac/main.bicep`: Resource group-scope entrypoint that wires RFC-64 parameters to modules
- `iac/modules/`: Domain-specific modules (identity, network, dns, kv, storage, acr, psql, app, gateway, search, cognitive-services, automation, diagnostics, bastion, vm-jumphost)
- `iac/lib/naming.bicep`: Shared naming helper for deterministic resource names
- `scripts/`: PowerShell scripts for RBAC and PostgreSQL setup, SSH utility for jump host access

### Critical Dependency Order

Modules have explicit `dependsOn` declarations to ensure correct deployment sequencing:

1. **Foundation**: `naming` → `diagnostics` → `identity` → `network`
2. **DNS and Private Networking**: `network` → `dns`
3. **Private Endpoint Modules**: All depend on `network`, `diagnostics`, and `dns`
   - `kv`, `storage`, `acr`, `search`, `cognitive-services`
4. **Modules with Secret Dependencies**: `psql` and `vm-jumphost` depend on `kv` + `secrets`
5. **Gateway Stack**: `public-ip` → `waf-policy` → `gateway` (also depends on `network` and `diagnostics`)

The `tests/unit/test_modules.py::test_static_dependency_rules` test validates these dependencies automatically.

### Parameter Management

**Single Source of Truth**: `tests/fixtures/params.dev.json` contains:
- Metadata: `subscriptionId`, `resourceGroupName`, `location`
- All RFC-64 parameters required by `main.bicep`

Test utilities automatically:
- Read parameters from this file
- Merge test-specific overrides when needed
- Filter parameters to match template declarations
- Validate required parameters via `tests/test_params.py`

### Testing Philosophy

The test suite is the **primary validation mechanism** for the infrastructure:

1. **Unit Tests** (`tests/unit/`): Validate individual modules in isolation with mocked dependencies. Use what-if mode by default. Auto-create resource group if missing.

2. **E2E Tests** (`tests/e2e/`): Validate full deployment with real Azure resources. What-if mode by default (safe). Actual deployment opt-in via `ENABLE_ACTUAL_DEPLOYMENT=true`.

3. **Parameter Tests** (`tests/test_params.py`): Validate that all required parameters are present in the params file.

4. **Dependency Tests**: Validate explicit module dependencies match architectural requirements.

Test output is configured via `pytest.ini` for verbose output with skip reasons by default.

## RBAC and Deployment Workflow

**Critical**: RBAC role assignments are **not executed automatically** during Bicep deployment. The deployment creates an Automation Account with no runbooks. After deployment:

1. Manually create runbooks in the Automation Account:
   - `assign-rbac-roles-uami`: Assigns UAMI roles (RG Contributor, KV Secrets Officer, Storage Blob Data Contributor, ACR Pull/Push, etc.)
   - `assign-rbac-roles-admin`: Assigns Customer Admin roles (RG Reader, KV Secrets User, Storage Blob Data Reader, ACR Pull, etc.)

2. Upload PowerShell content from `scripts/` directory

3. Publish runbooks in Azure Portal or via CLI

4. Execute runbooks to apply RBAC assignments (required after initial deployment and whenever roles need reapplication)

See README.md Section "RBAC Role Assignments" for complete instructions with CLI commands.

## Common Patterns and Gotchas

### Naming Conventions

- All resources prefixed with `vd-` (except storage/ACR which have no hyphens due to Azure constraints)
- Deterministic nanoids: 16 chars for most resources, 8 chars for storage/ACR
- Generated via `iac/lib/naming.bicep` using resource group name as seed

### VNet CIDR Management

**Important**: VNet and subnet CIDRs are **hardcoded** in `network.bicep`. The `vnetCidr` parameter is used for validation only. This design avoids Azure `cidrSubnet` function limitations and simplifies deployment.

- Changing VNet CIDR requires updating both the parameter value and the hardcoded values in `network.bicep`
- CIDR validation enforces /16, /20, or /24 prefix lengths
- Invalid CIDRs fail during deployment when `cidrSubnet` calculations execute

### Resource Group Persistence

**Test resource groups persist between runs by design**. This allows:
- Faster test iterations (no deletion/recreation overhead)
- Easier debugging (resources remain available for inspection)
- Incremental testing (update existing resources instead of full redeployment)

Manual cleanup when needed: `az group delete --name <rg-name> --yes`

### Deployment Mode

All deployments use **Complete mode**, which means resources not defined in the template **will be deleted**. This ensures resource group state matches the template exactly.

### Soft-Deleted Resources

Some Azure resources (Log Analytics Workspace, Cognitive Services) require explicit purging after deletion before they can be recreated with the same name. See "Troubleshooting and Cleanup" commands above.

## When Adding New Resources

1. **Create Module**: Add new module file in `iac/modules/<resource>.bicep`

2. **Add Names**: Update `iac/lib/naming.bicep` with deterministic name generation for the new resource

3. **Update Main**: Wire the module in `iac/main.bicep` with proper dependencies

4. **Add Parameters**: If new parameters required, add to `tests/fixtures/params.dev.json` and update `tests/test_params.py`

5. **Create Test Wrapper**: Add `tests/unit/fixtures/test-<resource>.bicep` with mocked dependencies

6. **Register Test**: Add to `MODULES` list in `tests/unit/test_modules.py`

7. **Validate Dependencies**: Run `pytest tests/unit/test_modules.py::test_static_dependency_rules` to ensure dependencies are correct

## Code Quality Standards

- Keep commits small with sentence-style messages
- Maintain deterministic names and idempotent templates
- Never use runtime-generated random names inside Bicep
- All changes must pass: compilation, parameter validation, what-if tests, and dependency tests
- Update documentation when behavior changes
- For networking changes, update both parameters and hardcoded CIDRs consistently

## Generated Files and Reports

All generated files, review reports, analysis outputs, and temporary files created by AI assistants or development tools should be stored in the `.vibedata/` directory:

- Code review reports
- Design review documents
- Analysis outputs
- Temporary planning files
- Generated documentation (that's not part of the main docs)
- AI assistant working files

**Rationale:** Keeps the repository root clean and makes it clear which files are generated vs. authored content.

**Git:** The `.vibedata/` folder should be in `.gitignore` to prevent generated files from being committed.

**Example:**
```bash
# Store review reports in .vibedata
.vibedata/code-review-2026-01-15.md
.vibedata/design-review-2026-01-15.md
.vibedata/analysis-output.json
```

## Reference Documentation

- **Testing**: See `tests/README.md` for comprehensive test documentation
- **Guidelines**: See `AGENTS.md` for development practices and standards
- **Steering**: See `.github/STEERING.md` for repository governance and PR checklists
- **Release Notes**: See `docs/RELEASE-NOTES-*.md` for version history
- **RFCs**: See `docs/rfc/RFC-*.md` for specification documents (not committed to git)