# Managed Application IaC for PRD-30

This repository contains the Bicep-based infrastructure for PRD-30 (managed application), aligned to RFC-42, RFC-64, and RFC-71. The modules include resource-level validation tooling for marketplace deployment.

## Layout

- `main.bicep` — resource group-scope entrypoint for managed application deployment; wires RFC-64 parameters into resource-group modules.
- `modules/*.bicep` — per-domain modules (identity, network, security, data, compute, gateway, ai, automation, diagnostics).
- `lib/` — shared helpers (naming per RFC-71, constants).
- `tests/fixtures/params.dev.json` — sample parameters for local testing.

## Parameters (RFC-64 names)

- `resourceGroupName` (replaces `resourceGroup` and `mrgName`), `location`, `contactEmail`, `adminObjectId`, `adminPrincipalType`
- `servicesVnetCidr`, `customerIpRanges`, `publisherIpRanges`
- `sku` (App Service Plan), `computeTier` (PostgreSQL), `aiServicesTier`
- Defaults/display-only: `appGwSku`, `appGwCapacity`, `storageGB`, `backupRetentionDays`, `retentionDays`

## Run locally

```bash
az group create -n vd-rg-dev-abc12345 -l eastus
az deployment group create \
  --resource-group vd-rg-dev-abc12345 \
  -f iac/main.bicep \
  -p @tests/fixtures/params.dev.json
```

For a dry run without changes:

```bash
az deployment group what-if \
  --resource-group vd-rg-dev-abc12345 \
  -f iac/main.bicep \
  -p @tests/fixtures/params.dev.json
```

## Testing

Run unit tests:

```bash
pytest tests/unit/test_modules.py -v
```

Run E2E tests (what-if mode, safe):

```bash
pytest tests/e2e/
```

Run E2E tests (actual deployment, opt-in):

```bash
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

Keep parameter names and casing aligned with RFC-64 to match the eventual Marketplace handoff.

## Release Notes

- 2026-01-05 — v0.5.0 RFC-71 deterministic naming: [docs/RELEASE-NOTES-2026-01-05-v0.5.0.md](docs/RELEASE-NOTES-2026-01-05-v0.5.0.md)
- 2026-01-03 — v0.4.0 module validator + RFC-64 params: [docs/RELEASE-NOTES-2026-01-03-v0.4.0.md](docs/RELEASE-NOTES-2026-01-03-v0.4.0.md)
- 2026-01-03 — v0.3.0 validator resource-level coverage: [docs/RELEASE-NOTES-2026-01-03-v0.3.0.md](docs/RELEASE-NOTES-2026-01-03-v0.3.0.md)
- 2026-01-03 — v0.2.0 dev/test strict enforcement: [docs/RELEASE-NOTES-2026-01-03-v0.2.0.md](docs/RELEASE-NOTES-2026-01-03-v0.2.0.md)
- 2026-01-03 — v0.1.0 baseline: [docs/RELEASE-NOTES-2026-01-03.md](docs/RELEASE-NOTES-2026-01-03.md)
