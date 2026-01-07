"""Parameterized unit tests for all Bicep modules."""
import sys
from pathlib import Path

# Add project root to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import pytest
from tests.unit.helpers.test_utils import (
    run_bicep_build,
    run_what_if,
    load_json_file
)

# Define all modules to test
MODULES = [
    ('diagnostics', 'test-diagnostics.bicep', 'params-diagnostics.json'),
    ('network', 'test-network.bicep', 'params-network.json'),
    ('data', 'test-data.bicep', 'params-data.json'),
    ('compute', 'test-compute.bicep', 'params-compute.json'),
    ('gateway', 'test-gateway.bicep', 'params-gateway.json'),
    ('ai', 'test-ai.bicep', 'params-ai.json'),
    ('identity', 'test-identity.bicep', 'params-identity.json'),
    ('security', 'test-security.bicep', 'params-security.json'),
    ('automation', 'test-automation.bicep', 'params-automation.json'),
    ('logic', 'test-logic.bicep', 'params-logic.json'),
    ('dns', 'test-dns.bicep', 'params-dns.json'),
]

FIXTURES_DIR = Path(__file__).parent / 'fixtures'


@pytest.mark.parametrize('module_name,bicep_file,params_file', MODULES)
class TestBicepModules:
    """Parameterized test suite for all Bicep modules."""

    def test_bicep_compiles(self, module_name, bicep_file, params_file):
        """Test that the module test wrapper compiles successfully."""
        bicep_path = FIXTURES_DIR / bicep_file
        success, output = run_bicep_build(bicep_path)
        assert success, f"Bicep compilation failed for {module_name}: {output}"

    def test_params_file_exists(self, module_name, bicep_file, params_file):
        """Test that parameter file exists."""
        params_path = FIXTURES_DIR / params_file
        assert params_path.exists(), f"Parameter file not found for {module_name}: {params_path}"

    def test_params_file_valid_json(self, module_name, bicep_file, params_file):
        """Test that parameter file is valid JSON."""
        params_path = FIXTURES_DIR / params_file
        try:
            params = load_json_file(params_path)
            assert 'parameters' in params, f"Invalid JSON structure for {module_name}"
        except Exception as e:
            pytest.fail(f"Invalid JSON in params file for {module_name}: {e}")

    def test_what_if_succeeds(self, module_name, bicep_file, params_file):
        """Test that what-if execution succeeds."""
        bicep_path = FIXTURES_DIR / bicep_file
        params_path = FIXTURES_DIR / params_file
        # resourceGroupName extracted from params file automatically
        success, output = run_what_if(bicep_path, params_path)
        # Note: This may fail if Azure CLI is not configured, which is OK for unit tests
        # In CI, this would be skipped if credentials are not available
        if not success and "not logged in" in output.lower():
            pytest.skip(f"Azure CLI not configured - skipping what-if test for {module_name}")
        assert success, f"What-if failed for {module_name}: {output}"

