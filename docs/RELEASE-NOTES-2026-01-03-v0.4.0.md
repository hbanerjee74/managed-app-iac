# Release Notes — 2026-01-03 (v0.4.0)

## Overview
- Aligns all parameters to RFC-64 names (resourceGroup, sku, computeTier, retentionDays, etc.).
- Adds WAF policy resource and validation for Application Gateway allow/deny rules.
- Introduces per-module validator expectations for quicker drift checks (diagnostics, identity, network, security, data, compute, automation, AI, gateway).
- Tags include contactEmail; identity wiring now passes LAW scope for contributor RBAC.

## Highlights
- New module expectations: `tests/validator/expected/modules/*.json` with matching parametric test runner.
- Gateway uses `ApplicationGatewayWebApplicationFirewallPolicies` instead of inline custom rules; validator asserts policy presence.
- Parameters: added display/defaulted values (appGwSku, appGwCapacity, storageGB, backupRetentionDays) and contactEmail.

## Testing
- `pytest -q` (5 passed, skips on module tests without ACTUAL_EXPECTATION_PATH)
- `python3 -m py_compile tests/validator/collect_actual_state.py tests/validator/compare_expectation.py tests/validator/test_modules.py`

## Upgrade Notes
- Update any callers/CI that referenced old param names (`appServicePlanSku`, `postgresComputeTier`, `lawRetentionDays`, `resourceGroupName`) to the RFC-64 equivalents.
- For module validator, collect actual state once and set `ACTUAL_EXPECTATION_PATH`.
