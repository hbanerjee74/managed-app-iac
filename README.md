# Managed Application IaC for PRD-30

This repository contains the Bicep-based infrastructure for PRD-30 (managed application), aligned to RFC-42, RFC-64, and RFC-71. The modules include resource-level validation tooling for marketplace deployment.

## Layout
- `main.bicep` — subscription-scope entrypoint; wires RFC-64 parameters into resource-group modules.
- `modules/*.bicep` — per-domain modules (identity, network, security, data, compute, gateway, ai, automation, diagnostics).
- `lib/` — shared helpers (naming per RFC-71, constants).
- `tests/fixtures/params.dev.json` — sample parameters for local testing.

## Parameters (RFC-64 names)
- `resourceGroup`, `location`, `contactEmail`, `adminObjectId`, `adminPrincipalType`
- `servicesVnetCidr`, `customerIpRanges`, `publisherIpRanges`
- `sku` (App Service Plan), `computeTier` (PostgreSQL), `aiServicesTier`
- Defaults/display-only: `appGwSku`, `appGwCapacity`, `storageGB`, `backupRetentionDays`, `retentionDays`

## Run locally
```bash
az group create -n rg-vibedata-dev -l eastus
az deployment sub create \
  -f iac/main.bicep \
  -l eastus \
  -p @tests/fixtures/params.dev.json
```

For a dry run without changes:
```bash
az deployment sub what-if -f iac/main.bicep -l eastus -p @tests/fixtures/params.dev.json
```

## Dev/test state check
To verify the live RG matches the Bicep in dev/test:
```bash
./tests/state_check/what_if.sh eastus tests/fixtures/params.dev.json
python tests/state_check/diff_report.py tests/state_check/what-if.json
```

Module-level validator (`ACTUAL_PATH` required):
```bash
python tests/validator/collect_actual_state.py rg-vibedata-dev > /tmp/actual.json
ACTUAL_PATH=/tmp/actual.json pytest tests/validator/test_modules.py
```

Per-module actual + teardown:
```bash
# collect only one module
python tests/validator/collect_actual_state.py rg-vibedata-dev --module network --output /tmp/network.json
ACTUAL_PATH=/tmp/network.json pytest tests/validator/test_modules.py -k network

# tear down resources for a module (irreversible)
# preview
./scripts/teardown/module_teardown.sh rg-vibedata-dev network --dry-run
# execute
./scripts/teardown/module_teardown.sh rg-vibedata-dev network
```

## Validating deployed state against expectation (optional)
1) Collect actual state (best-effort summary):
```bash
python tests/validator/collect_actual_state.py rg-vibedata-dev > /tmp/actual.json
```
2) Compare against template:
```bash
ACTUAL_EXPECTATION_PATH=/tmp/actual.json pytest tests/validator/test_expectation_template.py
```
Edit `tests/validator/expected/dev_expectation.template.json` to tighten or expand checks (placeholders like `<16>` validate nanoid lengths; lists are matched as subsets).

Keep parameter names and casing aligned with RFC-64 to match the eventual Marketplace handoff.

## Release Notes
- 2026-01-05 — v0.5.0 RFC-71 deterministic naming: [docs/RELEASE-NOTES-2026-01-05-v0.5.0.md](docs/RELEASE-NOTES-2026-01-05-v0.5.0.md)
- 2026-01-03 — v0.4.0 module validator + RFC-64 params: [docs/RELEASE-NOTES-2026-01-03-v0.4.0.md](docs/RELEASE-NOTES-2026-01-03-v0.4.0.md)
- 2026-01-03 — v0.3.0 validator resource-level coverage: [docs/RELEASE-NOTES-2026-01-03-v0.3.0.md](docs/RELEASE-NOTES-2026-01-03-v0.3.0.md)
- 2026-01-03 — v0.2.0 dev/test strict enforcement: [docs/RELEASE-NOTES-2026-01-03-v0.2.0.md](docs/RELEASE-NOTES-2026-01-03-v0.2.0.md)
- 2026-01-03 — v0.1.0 baseline: [docs/RELEASE-NOTES-2026-01-03.md](docs/RELEASE-NOTES-2026-01-03.md)
