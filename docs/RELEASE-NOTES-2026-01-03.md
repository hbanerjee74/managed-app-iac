# Release Notes — 2026-01-03 (v0.1.0)

## Overview
First end-to-end Bicep baseline for PRD-30 managed application infrastructure. Focus on RFC-71 compliance for naming, private access, and network layout; templates now build cleanly (`az bicep build`) and sample parameters align with Marketplace inputs.

## Highlights
- Added dedicated delegated subnet for PostgreSQL Flexible Server and wired it through data module and main entrypoint.
- Enforced private-only posture: all PaaS private endpoints now use correct RG-scoped DNS IDs and separate DNS zone-group resources; Automation Account kept private with PE + DNS.
- Fixed deterministic naming helper to use valid Bicep functions and subscription scope; all modules consume generated names.
- Corrected Application Gateway WAF: fixed capacity to 1 (RFC-71), OWASP 3.2 rules with customer/publisher allowlists and deny-all, SSL policy set to AppGwSslPolicy20220101S (TLS 1.2).
- Function App now uses managed identity–backed AzureWebJobsStorage settings; UAMI granted Storage Queue + Blob Data roles.
- Postgres deployment script uses delegated subnet, proper DNS zone, AAD-only auth, and deterministic forceUpdateTag.
- Clean sample parameters updated with `adminPrincipalType` for Marketplace wiring.

## Testing
- `az bicep build -f iac/main.bicep` (with AZURE_CONFIG_DIR/DOTNET_BUNDLE_EXTRACT_BASE_DIR) — PASS, zero warnings.

## Compatibility / Notes
- Automation remains stricter than RFC-71 (publicNetworkAccess disabled, private endpoint enabled) by design request.
- App Gateway backend lists still placeholder; listeners/backends/probes need real endpoints before go-live.
- Storage access tier/cool/hot not parameterized yet; defaults remain service defaults.

## References
- PRD-30 (Managed Application Infrastructure)
- RFC-71 (Infrastructure Standards)
- RFC-42 (Private networking) / RFC-64 (Parameters) for module wiring

