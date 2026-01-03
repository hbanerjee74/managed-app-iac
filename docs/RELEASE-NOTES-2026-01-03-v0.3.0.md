# Release Notes — 2026-01-03 (v0.3.0)

## Overview
Validator now operates at resource-level fidelity: expectation templates mirror Bicep-defined resources and properties, and the collector captures deployed state with sufficient detail to detect drift across networking, security, data, compute, AI, and automation components.

## Highlights
- Expanded expectation template lists every resource (VNet, NSGs, UAMI, PIP, KV, Storage, ACR, LAW, App Gateway, PostgreSQL Flexible Server, App Service Plan, Web/Function Apps, Search, AI, Automation, private DNS zones/links, storage subresources, diagnostic settings, role assignments, and all private endpoints + DNS zone groups) with deterministic placeholders (`<16>`, `<8>`, `<guid>`, `__ANY__`) for runtime values and IDs.
- Collector (`tests/validator/collect_actual_state.py`) now gathers resource-level properties: subnet delegations/NSGs/policies, NSG rules, managed identity IDs, public IP settings, KV/ST/ACR security flags, LAW retention/features + custom table schema, WAF config, PG auth/storage/HA, App Service networking + identity + app settings, private DNS wiring, storage subresources, diagnostic settings, and RBAC assignments.
- Comparator (`tests/validator/compare_expectation.py`) adds `<guid>` and `__ANY__` placeholders, stronger list matching, and resource-by-resource diff reporting to surface missing or mismatched objects.

## Testing
- Local run: `pytest` (offline suite) — 5 passed, 1 skipped (`test_expectation_template.py` skips without ACTUAL_EXPECTATION_PATH).
- How to run full validator:
  - `python tests/validator/collect_actual_state.py <rg> > /tmp/actual.json`
  - `ACTUAL_EXPECTATION_PATH=/tmp/actual.json pytest tests/validator/test_expectation_template.py`
  - Optional lint: `PYTHONPYCACHEPREFIX=/tmp python3 -m py_compile tests/validator/collect_actual_state.py tests/validator/compare_expectation.py`

## Notes
- The expectation template encodes deterministic names; ensure params/naming seed align before comparison.
