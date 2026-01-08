# Health Probes (WAF/AppGW + App Service Plan)

This folder owns the health probe apps and their tests. The build produces zip artifacts
that are packaged with the Marketplace bundle and consumed by IaC via run-from-package.

## Structure

- `apps/waf-health/` — WAF + App Gateway health Web App (non-containerized).
- `apps/appservice-plan-health/` — App Service Plan health Web App (non-containerized).
- `tests/` — Health-specific tests (artifact presence and deployed app checks).

## Artifacts

Builds must produce these zip files at repo root:

- `artifacts/waf-health.zip`
- `artifacts/appservice-plan-health.zip`

IaC uses `WEBSITE_RUN_FROM_PACKAGE` to point to these artifacts in the Marketplace payload.

## Tests

Run health-specific checks (opt-in):

```bash
HEALTH_VALIDATE_ARTIFACTS=true pytest health/tests/test_health_artifacts.py -v
HEALTH_VALIDATE_APPS=true ENABLE_ACTUAL_DEPLOYMENT=true pytest health/tests/test_health_apps.py -v
```
