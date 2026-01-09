# Repository Guidelines (IaC for PRD-30)

## Scope & Current State

- Project focuses solely on Azure IaC for PRD-30 (managed application infrastructure). The prior Notion converter code has been removed.
- IaC lives under `iac/` with Bicep modules; tests live under `tests/` (param checks, unit tests, e2e tests).

## Project Structure

- `iac/main.bicep` — resource group-scope entrypoint for managed application deployment; wires RFC-64 parameters to RG modules.
- `iac/modules/` — domain modules (`identity`, `network`, `dns`, `kv`, `storage`, `acr`, `psql`, `app`, `gateway`, `search`, `cognitive-services`, `automation`, `diagnostics`).
- `iac/lib/naming.bicep` — deterministic per-resource nanoid naming (RFC-71).
- `tests/fixtures/params.dev.json` — single source of truth for RG name, location, subscription ID, and all parameters.
- `tests/test_params.py` — required param presence check.
- `tests/unit/` — unit tests for individual modules (what-if mode, auto-creates RG if needed).
- `tests/e2e/` — end-to-end tests for full deployment (what-if and actual deployment modes).
- `pytest.ini` — pytest configuration for verbose output by default.

## Deployment & Validation

**Recommended approach: Use pytest tests for validation and deployment.**

- **Unit tests** (what-if mode, auto-creates RG if needed): `pytest tests/unit/test_modules.py -v`
- **E2E what-if tests** (safe, no actual deployment): `pytest tests/e2e/`
- **E2E actual deployment** (opt-in, creates real resources): `ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment`
- **Keep resource group for debugging**: `KEEP_RESOURCE_GROUP=true` (with `ENABLE_ACTUAL_DEPLOYMENT=true`)
- **Manual deployment** (if needed): `az deployment group what-if --resource-group <rg-name> -f iac/main.bicep -p @tests/fixtures/params.dev.json` (or `az deployment group create --mode Complete --resource-group <rg-name> -f iac/main.bicep -p @tests/fixtures/params.dev.json`)
- **Diagnostics**: LAW with custom table `VibeData_Operations_CL`; all resources emit diagnostics to LAW.

See [`tests/README.md`](tests/README.md) for comprehensive test documentation.

## Naming & Standards

- Per-resource nanoids (16-char; storage 8) per RFC-71; helper in `iac/lib/naming.bicep`.
- VNet and subnets use hardcoded CIDRs: VNet `10.20.0.0/16`, subnets `/24` (10.20.0.0/24 through 10.20.4.0/24). This simplifies deployment and avoids Azure `cidrSubnet` limitations.
- Public access disabled for all PaaS; private endpoints + DNS zones per RFC-42/71.

## Identities & RBAC

- Always create/use `vibedata-uami-*`; RG Contributor + resource-scoped roles (KV Secrets Officer, Storage Blob Data Contributor, ACR Pull/Push). Automation Job Operator assigned to `adminObjectId`.
- `adminPrincipalType` param (User/Group) for RG Reader assignment.
- **Managed Application Requirements**: All role assignments use `delegatedManagedIdentityResourceId` property for cross-tenant scenarios. Includes 30-second propagation delay after UAMI creation to allow identity propagation across tenants.
- **Scope**: All RBAC assignments occur at resource group scope (subscription-scope roles like Cost Management Reader are not assigned).

## Postgres Roles

- Deployment script attempts to create `vd_dbo`/`vd_reader` and grant UAMI; relies on `psql` availability in deploymentScripts runtime. If it fails, run equivalent via runbook/CI agent.

## App Gateway

- WAF_v2 with customer/publisher IP allowlists and deny-all; connection draining enabled.
- **Placeholder resources**: Minimal placeholder backend pool, listener, and routing rule added to satisfy Azure validation requirements (see `.vibedata/spec-changes.md` section 12). Actual app endpoints should be configured when ready.

## Tests & Quality

**Test suite is the primary validation method:**

- **Parameter validation**: `pytest tests/test_params.py` — validates required params are present
- **Unit tests**: `pytest tests/unit/test_modules.py -v` — validates individual modules (what-if mode)
- **E2E tests**: `pytest tests/e2e/` — validates full deployment (what-if mode by default)
- **Verbose output**: Configured in `pytest.ini` (shows test names and skip reasons by default)
- **Debugging**: Set `KEEP_RESOURCE_GROUP=true` to keep resources after E2E deployment tests

**Test output options:**

- `-v` or `--verbose` — Show test names (default)
- `-rs` — Show skip reasons
- `-ra` — Show all test outcomes
- `-vv` — Extra verbose

See [`tests/README.md`](tests/README.md) for comprehensive test documentation including CI/CD integration.

## Git & Ignore Rules

- `.gitignore` ignores `.venv/`, `.DS_Store`, and `docs/PRD*.md` / `docs/RFC*.md` (intentional to keep specs out of git).

## Coding/PR Practices

- Keep commits small, sentence-style messages.
- When adding params/resources, update `tests/fixtures/params.dev.json`, `test_params.py`, and wiring in `main.bicep`.
- Maintain deterministic names and idempotent templates; avoid random runtime names inside Bicep.
