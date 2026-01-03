# IaC scaffold for PRD-30

This folder holds the Bicep deployment for PRD-30 (managed application infrastructure). Files are stubs; fill out modules per PRD-30, RFC-42, RFC-64, and RFC-71.

## Layout
- `main.bicep` — subscription-scope entrypoint; wires RFC-64 parameters into resource-group modules.
- `modules/*.bicep` — per-domain modules (identity, network, security, data, compute, gateway, ai, automation, diagnostics).
- `lib/` — shared helpers (naming, constants).
- `params.dev.json` — sample parameters for local testing.

## Run locally
```bash
az group create -n rg-vibedata-dev -l eastus
az deployment sub create \
  -f iac/main.bicep \
  -l eastus \
  -p @iac/params.dev.json
```

For a dry run without changes:
```bash
az deployment sub what-if -f iac/main.bicep -l eastus -p @iac/params.dev.json
```

## Dev/test state check
To verify the live RG matches the Bicep in dev/test:
```bash
./tests/state_check/what_if.sh eastus iac/params.dev.json
python tests/state_check/diff_report.py tests/state_check/what-if.json
```

Keep parameter names and casing aligned with RFC-64 to match the eventual Marketplace handoff.

## Release Notes
- 2026-01-03 — v0.1.0 baseline: docs/RELEASE-NOTES-2026-01-03.md
