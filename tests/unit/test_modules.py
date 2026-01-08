"""Parameterized unit tests for all Bicep modules."""
import sys
from pathlib import Path

# Add project root to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import pytest
from tests.unit.helpers.test_utils import (
    run_bicep_build,
    run_bicep_build_with_params,
    run_what_if,
    load_json_file
)
from tests.unit.helpers.what_if_parser import parse_what_if_output

# Define all modules to test (no params files needed - all params come from params.dev.json)
MODULES = [
    ('diagnostics', 'test-diagnostics.bicep'),
    ('network', 'test-network.bicep'),
    ('data', 'test-data.bicep'),
    ('compute', 'test-compute.bicep'),
    ('public-ip', 'test-public-ip.bicep'),
    ('waf-policy', 'test-waf-policy.bicep'),
    ('gateway', 'test-gateway.bicep'),
    ('search', 'test-search.bicep'),
    ('cognitive-services', 'test-cognitive-services.bicep'),
    ('identity', 'test-identity.bicep'),
    ('kv', 'test-kv.bicep'),
    ('storage', 'test-storage.bicep'),
    ('acr', 'test-acr.bicep'),
    ('automation', 'test-automation.bicep'),
    ('logic', 'test-logic.bicep'),
    ('dns', 'test-dns.bicep'),
]

FIXTURES_DIR = Path(__file__).parent / 'fixtures'


@pytest.mark.parametrize('module_name,bicep_file', MODULES)
class TestBicepModules:
    """Parameterized test suite for all Bicep modules."""

    @pytest.fixture(scope='function', autouse=False)
    def cached_what_if_output(self, module_name, bicep_file):
        """Cache what-if output for the module to avoid redundant API calls.
        
        This fixture runs what-if once per test function and caches the parsed output.
        Changed to function scope to match parametrized values scope.
        
        Args:
            module_name: Module name from parametrization
            bicep_file: Bicep file name from parametrization
        
        Returns:
            dict: Parsed what-if output with keys: 'status', 'changes', 'resource_changes', 'error', 'properties'
            None: If what-if fails or Azure CLI is not configured (tests should skip)
        """
        
        bicep_path = FIXTURES_DIR / bicep_file
        
        # Run what-if once per module (no params_file - uses shared params.dev.json)
        success, output = run_what_if(bicep_path)
        
        # Handle failures gracefully
        if not success:
            # Check if it's an authentication issue (should skip, not fail)
            if "not logged in" in output.lower() or "authentication" in output.lower():
                pytest.skip(f"Azure CLI not configured - skipping what-if cache for {module_name}")
            # For other failures, return None (tests can check for this)
            return None
        
        # Parse and cache the output
        try:
            parsed_output = parse_what_if_output(output)
            return parsed_output
        except Exception as e:
            # If parsing fails, return None
            return None

    def test_bicep_compiles(self, module_name, bicep_file):
        """Test that the module test wrapper compiles successfully."""
        bicep_path = FIXTURES_DIR / bicep_file
        success, output = run_bicep_build(bicep_path)
        assert success, f"Bicep compilation failed for {module_name}: {output}"

    def test_what_if_succeeds(self, module_name, bicep_file, cached_what_if_output):
        """Test that what-if execution succeeds.
        
        Uses cached what-if output from fixture to avoid redundant API calls.
        """
        # Check if cached output is available (None indicates failure)
        if cached_what_if_output is None:
            # If cached output is None, it means what-if failed
            # Try running it once more to get the error message
            bicep_path = FIXTURES_DIR / bicep_file
            success, output = run_what_if(bicep_path)
            if not success and "not logged in" in output.lower():
                pytest.skip(f"Azure CLI not configured - skipping what-if test for {module_name}")
            pytest.fail(f"What-if failed for {module_name}: {output}")
        
        # Verify cached output has expected structure
        assert 'status' in cached_what_if_output, f"Cached what-if output missing 'status' for {module_name}"
        assert cached_what_if_output.get('status') != 'Failed', \
            f"What-if status is 'Failed' for {module_name}: {cached_what_if_output.get('error', 'Unknown error')}"

    def test_cidr_validation_valid_ranges(self, module_name, bicep_file):
        """Test that valid CIDR ranges (/16-/24) allow Bicep compilation.
        
        Only runs for network module. Other modules are skipped.
        NOTE: Network module now uses hardcoded CIDRs, so this test is skipped.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        # Network module now uses hardcoded CIDRs (10.20.0.0/16 VNet, /24 subnets)
        # CIDR validation tests are no longer applicable
        pytest.skip("Network module uses hardcoded CIDRs - CIDR validation tests no longer applicable")

    def test_cidr_validation_invalid_prefix(self, module_name, bicep_file):
        """Test that invalid CIDR prefix ranges cause assert failure.
        
        Tests both too-small prefixes (/15 and below) and too-large prefixes (/25 and above).
        Only runs for network module.
        NOTE: Network module now uses hardcoded CIDRs, so this test is skipped.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        # Network module now uses hardcoded CIDRs (10.20.0.0/16 VNet, /24 subnets)
        # CIDR validation tests are no longer applicable
        pytest.skip("Network module uses hardcoded CIDRs - CIDR validation tests no longer applicable")

    def test_cidr_validation_invalid_format(self, module_name, bicep_file):
        """Test that invalid CIDR formats cause assert failure.
        
        Tests missing prefix, invalid IP addresses, non-numeric prefix, etc.
        Only runs for network module.
        NOTE: Network module now uses hardcoded CIDRs, so this test is skipped.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        # Network module now uses hardcoded CIDRs (10.20.0.0/16 VNet, /24 subnets)
        # CIDR validation tests are no longer applicable
        pytest.skip("Network module uses hardcoded CIDRs - CIDR validation tests no longer applicable")
