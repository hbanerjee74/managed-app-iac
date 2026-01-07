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

    def test_cidr_validation_valid_ranges(self, module_name, bicep_file, params_file):
        """Test that valid CIDR ranges (/16-/24) allow Bicep compilation.
        
        Only runs for network module. Other modules are skipped.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        import tempfile
        import json
        import os
        
        valid_cidrs = [
            '10.20.0.0/16',  # Lower bound
            '10.20.0.0/20',  # Middle range
            '10.20.0.0/24',  # Upper bound
        ]
        
        bicep_path = FIXTURES_DIR / bicep_file
        
        # Load shared params for resourceGroupName and location
        shared_params_path = Path(__file__).parent.parent / 'fixtures' / 'params.dev.json'
        shared_params = load_json_file(shared_params_path)
        
        for cidr in valid_cidrs:
            # Create temporary params file with valid CIDR
            params_data = {
                "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {
                    "servicesVnetCidr": {"value": cidr},
                    "resourceGroupName": {"value": shared_params['metadata']['resourceGroupName']},
                    "location": {"value": shared_params['metadata']['location']}
                }
            }
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_file:
                json.dump(params_data, tmp_file, indent=2)
                tmp_params_file = tmp_file.name
            
            try:
                success, output = run_bicep_build_with_params(bicep_path, Path(tmp_params_file))
                # parseCidr validates format, and we check prefix length in tests
                # Note: assert statements in Bicep have syntax issues, so validation happens via parseCidr + tests
                assert success, f"Bicep validation should succeed for valid CIDR {cidr}, but failed: {output}"
            finally:
                try:
                    os.unlink(tmp_params_file)
                except Exception:
                    pass

    def test_cidr_validation_invalid_prefix(self, module_name, bicep_file, params_file):
        """Test that invalid CIDR prefix ranges cause assert failure.
        
        Tests both too-small prefixes (/15 and below) and too-large prefixes (/25 and above).
        Only runs for network module.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        import tempfile
        import json
        import os
        
        invalid_cidrs = [
            ('10.20.0.0/15', 'too small prefix (network too large)'),
            ('10.20.0.0/14', 'even smaller prefix'),
            ('10.20.0.0/8', 'very small prefix'),
            ('10.20.0.0/25', 'too large prefix (network too small)'),
            ('10.20.0.0/26', 'even larger prefix'),
            ('10.20.0.0/30', 'very large prefix'),
        ]
        
        bicep_path = FIXTURES_DIR / bicep_file
        
        # Load shared params for resourceGroupName and location
        shared_params_path = Path(__file__).parent.parent / 'fixtures' / 'params.dev.json'
        shared_params = load_json_file(shared_params_path)
        
        for cidr, description in invalid_cidrs:
            # Create temporary params file with invalid CIDR
            params_data = {
                "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {
                    "servicesVnetCidr": {"value": cidr},
                    "resourceGroupName": {"value": shared_params['metadata']['resourceGroupName']},
                    "location": {"value": shared_params['metadata']['location']}
                }
            }
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_file:
                json.dump(params_data, tmp_file, indent=2)
                tmp_params_file = tmp_file.name
            
            try:
                success, output = run_bicep_build_with_params(bicep_path, Path(tmp_params_file))
                # parseCidr will fail for invalid formats, and subnet calculation will fail for out-of-range prefixes
                assert not success, f"Bicep validation should fail for invalid CIDR {cidr} ({description}), but succeeded"
                # Check for parseCidr errors or subnet calculation errors
                assert ('parseCidr' in output.lower() or 'subnet' in output.lower() or 'error' in output.lower() or 'invalid' in output.lower()), \
                    f"Expected error not found in output for {cidr}. Output: {output}"
            finally:
                try:
                    os.unlink(tmp_params_file)
                except Exception:
                    pass

    def test_cidr_validation_invalid_format(self, module_name, bicep_file, params_file):
        """Test that invalid CIDR formats cause assert failure.
        
        Tests missing prefix, invalid IP addresses, non-numeric prefix, etc.
        Only runs for network module.
        """
        if module_name != 'network':
            pytest.skip(f"CIDR validation only applies to network module, skipping for {module_name}")
        
        import tempfile
        import json
        import os
        
        invalid_formats = [
            ('10.20.0.0', 'missing prefix'),
            ('10.20.0.0/', 'empty prefix'),
            ('not-an-ip/24', 'invalid IP address'),
            ('10.20.0.0/abc', 'non-numeric prefix'),
        ]
        
        bicep_path = FIXTURES_DIR / bicep_file
        
        # Load shared params for resourceGroupName and location
        shared_params_path = Path(__file__).parent.parent / 'fixtures' / 'params.dev.json'
        shared_params = load_json_file(shared_params_path)
        
        for invalid_cidr, description in invalid_formats:
            # Create temporary params file with invalid CIDR format
            params_data = {
                "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {
                    "servicesVnetCidr": {"value": invalid_cidr},
                    "resourceGroupName": {"value": shared_params['metadata']['resourceGroupName']},
                    "location": {"value": shared_params['metadata']['location']}
                }
            }
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_file:
                json.dump(params_data, tmp_file, indent=2)
                tmp_params_file = tmp_file.name
            
            try:
                success, output = run_bicep_build_with_params(bicep_path, Path(tmp_params_file))
                assert not success, f"Bicep validation should fail for invalid CIDR format '{invalid_cidr}' ({description}), but succeeded"
                # parseCidr will fail for invalid formats, check for parseCidr errors or Bicep syntax errors
                assert ('parseCidr' in output.lower() or 'Error BCP' in output.lower() or 'invalid' in output.lower()), \
                    f"Expected error message not found in output for '{invalid_cidr}'. Output: {output}"
            finally:
                try:
                    os.unlink(tmp_params_file)
                except Exception:
                    pass

