# Release Notes — 2026-01-03 (v0.2.0)

## Overview
Added strict drift detection and enforcement workflow for dev/test environments while keeping Marketplace deployments clean and Bicep-first.

## Highlights
- New RG-scope entrypoint (`iac/main.rg.bicep`) for dev/test deployments using the same RFC-64 parameters.
- Strict enforcement scripts (Complete mode) for CI/CD:
  - `scripts/deploy/what_if_rg.sh` for what-if drift detection.
  - `scripts/deploy/apply_rg.sh` for apply in CD/manual workflows.
- README updated with dev/test strict enforcement instructions.
- RG guardrail: deployment scripts require the target RG to be tagged `IAC=true`.
- Deviation from PRD/RFC subnet list: adds an extra delegated `/28` `snet-psql` for PostgreSQL Flexible Server (in addition to PRD-30/RFC-71 subnets). Rationale: dedicated delegation for PG private access; keeps PE subnet separate.
- CI hooks (recommended): `az bicep build` for `main.bicep` and `main.rg.bicep`, `what_if_rg.sh` + `diff_report.py` as a gate; added shellcheck-based lint test.
- Expectation template added: `tests/validator/expected/dev_expectation.template.json` with placeholder-based matching; comparison helper `tests/validator/compare_expectation.py` and pytest `test_expectation_template.py` (run with `ACTUAL_EXPECTATION_PATH` env).

## Testing
- `az bicep build -f iac/main.bicep --outdir /tmp/bicep`
- `az bicep build -f iac/main.rg.bicep --outdir /tmp/bicep`
- `pytest tests/test_shell_scripts.py` (runs shellcheck if installed)

## Notes
- Strict enforcement uses Complete mode at RG scope; ensure the RG contains only managed resources to avoid accidental deletions.
