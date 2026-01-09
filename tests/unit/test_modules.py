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
    load_json_file,
    SHARED_PARAMS_FILE
)
from tests.unit.helpers.what_if_parser import parse_what_if_output

# Define all modules to test (no params files needed - all params come from params.dev.json)
MODULES = [
    ('diagnostics', 'test-diagnostics.bicep'),
    ('network', 'test-network.bicep'),
    ('psql', 'test-psql.bicep'),
    ('psql-roles', 'test-psql-roles.bicep'),
    ('app', 'test-app.bicep'),
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
    ('dns', 'test-dns.bicep'),
    ('bastion', 'test-bastion.bicep'),
    ('vm-jumphost', 'test-vm-jumphost.bicep'),
    ('rbac', 'test-rbac.bicep'),
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
        """Test that valid CIDR ranges (/16, /20, /24) allow template validation.
        
        Only runs for network module. Other modules are skipped.
        Uses what-if mode to evaluate assertions with different CIDR values.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        import tempfile
        import json
        
        bicep_path = FIXTURES_DIR / bicep_file
        shared_params = load_json_file(SHARED_PARAMS_FILE)
        
        # Valid CIDR ranges to test
        valid_cidrs = ['10.20.0.0/16', '10.20.0.0/20', '10.20.0.0/24']
        
        for cidr in valid_cidrs:
            # Create temporary params file with only vnetCidr (run_what_if will merge with shared params and filter)
            test_params = {
                'parameters': {
                    'vnetCidr': {'value': cidr}
                }
            }
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_file:
                json.dump(test_params, tmp_file, indent=2)
                tmp_params_file = tmp_file.name
            
            try:
                # Test what-if with this CIDR (run_what_if filters parameters to only those declared in template)
                success, output = run_what_if(bicep_path, params_file=Path(tmp_params_file), ensure_rg_exists=False)
                assert success, f"What-if failed for valid CIDR {cidr}: {output}"
            finally:
                # Clean up temp file
                Path(tmp_params_file).unlink(missing_ok=True)

    def test_cidr_validation_invalid_prefix(self, module_name, bicep_file):
        """Test that invalid CIDR prefix ranges cause assert failure.
        
        Tests both too-small prefixes (/15 and below) and too-large prefixes (/25 and above).
        Only runs for network module.
        Uses what-if mode to evaluate assertions.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        import tempfile
        import json
        
        bicep_path = FIXTURES_DIR / bicep_file
        shared_params = load_json_file(SHARED_PARAMS_FILE)
        
        # Invalid CIDR prefix ranges to test
        invalid_cidrs = ['10.20.0.0/15', '10.20.0.0/14', '10.20.0.0/8', '10.20.0.0/25', '10.20.0.0/26', '10.20.0.0/30']
        
        for cidr in invalid_cidrs:
            # Create temporary params file with only vnetCidr (run_what_if will merge with shared params and filter)
            test_params = {
                'parameters': {
                    'vnetCidr': {'value': cidr}
                }
            }
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_file:
                json.dump(test_params, tmp_file, indent=2)
                tmp_params_file = tmp_file.name
            
            try:
                # Test what-if with this CIDR (should fail due to validation)
                success, output = run_what_if(bicep_path, params_file=Path(tmp_params_file), ensure_rg_exists=False)
                # For invalid CIDRs, what-if should fail (validation failure or array index error)
                # Note: Some invalid CIDRs might fail during parsing, which is also acceptable
                assert not success or 'error' in output.lower() or 'invalid' in output.lower() or 'index' in output.lower() or 'out of range' in output.lower(), \
                    f"What-if unexpectedly succeeded for invalid CIDR {cidr}. Validation should have failed."
            finally:
                # Clean up temp file
                Path(tmp_params_file).unlink(missing_ok=True)

    def test_cidr_validation_invalid_format(self, module_name, bicep_file):
        """Test that invalid CIDR formats cause assert failure.
        
        Tests missing prefix, invalid IP addresses, non-numeric prefix, etc.
        Only runs for network module.
        Uses what-if mode to evaluate assertions.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        import tempfile
        import json
        
        bicep_path = FIXTURES_DIR / bicep_file
        shared_params = load_json_file(SHARED_PARAMS_FILE)
        
        # Invalid CIDR formats to test
        invalid_formats = [
            '10.20.0.0',  # Missing prefix
            '10.20.0',    # Invalid IP (only 3 octets)
            '10.20.0.0.0/16',  # Invalid IP (5 octets)
            '256.20.0.0/16',   # Invalid IP (octet > 255)
            '10.20.0.0/abc',   # Non-numeric prefix
        ]
        
        for invalid_cidr in invalid_formats:
            # Create temporary params file with only vnetCidr (run_what_if will merge with shared params and filter)
            test_params = {
                'parameters': {
                    'vnetCidr': {'value': invalid_cidr}
                }
            }
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_file:
                json.dump(test_params, tmp_file, indent=2)
                tmp_params_file = tmp_file.name
            
            try:
                # Test what-if with this CIDR (should fail due to validation or parsing error)
                success, output = run_what_if(bicep_path, params_file=Path(tmp_params_file), ensure_rg_exists=False)
                # For invalid formats, what-if should fail (validation failure or parsing error)
                assert not success or 'error' in output.lower() or 'invalid' in output.lower() or 'parse' in output.lower() or 'split' in output.lower(), \
                    f"What-if unexpectedly succeeded for invalid CIDR format '{invalid_cidr}'. Should have failed."
            finally:
                # Clean up temp file
                Path(tmp_params_file).unlink(missing_ok=True)
