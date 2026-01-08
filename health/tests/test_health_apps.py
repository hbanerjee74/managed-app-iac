"""Health app deployment checks (opt-in)."""
import json
import os
import subprocess
from pathlib import Path
import pytest

DEPLOYMENT_OUTPUT = Path(__file__).parent.parent.parent / 'tests' / 'e2e' / 'deployment-output.json'
PARAMS_FILE = Path(__file__).parent.parent.parent / 'tests' / 'fixtures' / 'params.dev.json'


def get_deployment_outputs():
    """Return deployment outputs from saved deployment output file."""
    if not DEPLOYMENT_OUTPUT.exists():
        return None
    try:
        deployment_data = json.loads(DEPLOYMENT_OUTPUT.read_text())
        return deployment_data.get('properties', {}).get('outputs', {})
    except Exception:
        return None


def get_resource_group_from_params():
    """Extract resource group name from params file metadata (or parameters for backward compatibility)."""
    try:
        params_data = json.loads(PARAMS_FILE.read_text())
        rg_name = params_data.get('metadata', {}).get('resourceGroupName', '')
        if rg_name:
            return rg_name
        return params_data.get('parameters', {}).get('resourceGroupName', {}).get('value', '')
    except Exception:
        return ''


@pytest.mark.skipif(
    os.getenv('HEALTH_VALIDATE_APPS', 'false').lower() != 'true',
    reason="Set HEALTH_VALIDATE_APPS=true to validate health app deployments."
)
@pytest.mark.skipif(
    os.getenv('ENABLE_ACTUAL_DEPLOYMENT', 'false').lower() != 'true',
    reason="Actual deployment disabled. Set ENABLE_ACTUAL_DEPLOYMENT=true to enable."
)
def test_health_apps_deployed():
    """Validate health web apps deployed and configured to run from artifacts."""
    outputs = get_deployment_outputs()
    if not outputs:
        pytest.skip("Deployment outputs not available - run tests/e2e/test_main.py::TestMainBicep::test_actual_deployment first")

    waf_app_name = outputs.get('healthWafAppName', {}).get('value')
    asp_app_name = outputs.get('healthAspAppName', {}).get('value')
    rg_name = outputs.get('resourceGroupName', {}).get('value') or get_resource_group_from_params()
    if not waf_app_name or not asp_app_name:
        pytest.fail("Missing health app output names (healthWafAppName/healthAspAppName) in deployment outputs")
    if not rg_name:
        pytest.fail("Missing resourceGroupName output in deployment outputs")

    try:
        for app_name, expected_zip in [
            (waf_app_name, 'artifacts/waf-health.zip'),
            (asp_app_name, 'artifacts/appservice-plan-health.zip'),
        ]:
            result = subprocess.run(
                [
                    'az', 'webapp', 'config', 'appsettings', 'list',
                    '--resource-group', rg_name,
                    '--name', app_name,
                    '--output', 'json'
                ],
                capture_output=True,
                text=True,
                check=True
            )
            settings = json.loads(result.stdout)
            run_from = next(
                (s.get('value') for s in settings if s.get('name') == 'WEBSITE_RUN_FROM_PACKAGE'),
                None
            )
            assert run_from, f"WEBSITE_RUN_FROM_PACKAGE not set for {app_name}"
            assert expected_zip in run_from, (
                f"{app_name} not configured to run from {expected_zip}. Value: {run_from}"
            )
    except FileNotFoundError:
        pytest.skip("Azure CLI not found")
