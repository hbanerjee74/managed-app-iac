# Repository Guidelines (IaC for PRD-30)

## Scope & Current State
- Project focuses solely on Azure IaC for PRD-30 (managed application infrastructure). The prior Notion converter code has been removed.
- IaC lives under `iac/` with Bicep modules; tests live under `tests/` (param checks, state_check, validator stubs).

## Project Structure
- `iac/main.bicep` — subscription-scope entrypoint wiring RFC-64 parameters to RG modules.
- `iac/modules/` — domain modules (`identity`, `network`, `dns`, `security`, `data`, `compute`, `gateway`, `ai`, `automation`, `diagnostics`).
- `iac/lib/naming.bicep` — deterministic per-resource nanoid naming (RFC-71).
- `tests/fixtures/params.dev.json` — sample params for dev/what-if.
- `tests/test_params.py` — required param presence check.
- `tests/state_check/` — `what_if.sh` + `diff_report.py` to compare Bicep vs. RG.
- `tests/validator/` — placeholder for post-deploy actual/expected JSON comparison.

## Deployment & Validation
- Create RG, then run: `az deployment sub what-if -f iac/main.bicep -l <region> -p @tests/fixtures/params.dev.json` (or `az deployment sub create ...`).
- State check: `./tests/state_check/what_if.sh <region> tests/fixtures/params.dev.json && python tests/state_check/diff_report.py tests/state_check/what-if.json`.
- Diagnostics: LAW with custom table `VibeData_Operations_CL`; all resources emit diagnostics to LAW.

## Naming & Standards
- Per-resource nanoids (16-char; storage 8) per RFC-71; helper in `iac/lib/naming.bicep`.
- Subnets derived from `servicesVnetCidr`: /27 appgw, /25 aks, /28 appsvc, /28 private-endpoints; CIDR range asserted /16–/24.
- Public access disabled for all PaaS; private endpoints + DNS zones per RFC-42/71.

## Identities & RBAC
- Always create/use `vibedata-uami-*`; RG Contributor + resource-scoped roles (KV Secrets Officer, Storage Blob Data Contributor, ACR Pull/Push, Postgres Admin). Automation Job Operator assigned to `adminObjectId`.
- `adminPrincipalType` param (User/Group) for RG Reader assignment.

## Postgres Roles
- Deployment script attempts to create `vd_dbo`/`vd_reader` and grant UAMI; relies on `psql` availability in deploymentScripts runtime. If it fails, run equivalent via runbook/CI agent.

## App Gateway
- WAF_v2 with customer/publisher IP allowlists and deny-all; connection draining enabled. Listeners/backends/probes intentionally empty until app endpoints are ready.

## Tests & Quality
- Minimal pytest: `pytest tests/test_params.py` (requires pytest installed).
- What-if/diag checks are optional dev utilities; not wired into CI.

## Git & Ignore Rules
- `.gitignore` ignores `.venv/`, `.DS_Store`, and `docs/PRD*.md` / `docs/RFC*.md` (intentional to keep specs out of git).

## Coding/PR Practices
- Keep commits small, sentence-style messages.
- When adding params/resources, update `tests/fixtures/params.dev.json`, `test_params.py`, and wiring in `main.bicep`.
- Maintain deterministic names and idempotent templates; avoid random runtime names inside Bicep.

