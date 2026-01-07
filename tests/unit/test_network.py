"""Unit tests for network module."""
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
from tests.unit.helpers.what_if_parser import (
    parse_what_if_output,
    validate_resource_created,
    validate_no_unexpected_changes,
    validate_no_deletions
)


FIXTURES_DIR = Path(__file__).parent / 'fixtures'
BICEP_FILE = FIXTURES_DIR / 'test-network.bicep'
PARAMS_FILE = FIXTURES_DIR / 'params-network.json'

# Expected resources for network module
EXPECTED_RESOURCES = [
    'virtualNetworks',
    'networkSecurityGroups',
    'subnets'
]


class TestNetworkModule:
    """Test suite for network module."""

    def test_bicep_compiles(self):
        """Test that the network test wrapper compiles successfully."""
        success, output = run_bicep_build(BICEP_FILE)
        assert success, f"Bicep compilation failed: {output}"

    def test_params_file_exists(self):
        """Test that parameter file exists."""
        assert PARAMS_FILE.exists(), f"Parameter file not found: {PARAMS_FILE}"

    def test_params_file_valid_json(self):
        """Test that parameter file is valid JSON."""
        try:
            params = load_json_file(PARAMS_FILE)
            assert 'parameters' in params
        except Exception as e:
            pytest.fail(f"Invalid JSON in params file: {e}")

    def test_what_if_succeeds(self):
        """Test that what-if execution succeeds and returns valid output."""
        # resourceGroupName extracted from params file automatically
        success, output = run_what_if(BICEP_FILE, PARAMS_FILE)
        if not success and "not logged in" in output.lower():
            pytest.skip("Azure CLI not configured - skipping what-if test")
        assert success, f"What-if failed: {output}"
        
        # Parse what-if output
        parsed = parse_what_if_output(output)
        assert 'error' not in parsed or parsed['error'] is None, f"What-if returned error: {parsed.get('error')}"

    def test_what_if_creates_expected_resources(self):
        """Test that what-if shows expected resources would be created."""
        # resourceGroupName extracted from params file automatically
        success, output = run_what_if(BICEP_FILE, PARAMS_FILE)
        if not success and "not logged in" in output.lower():
            pytest.skip("Azure CLI not configured - skipping what-if test")
        
        parsed = parse_what_if_output(output)
        resource_changes = parsed.get('resource_changes', [])
        
        # Check that VNet would be created
        vnet_created = validate_resource_created(resource_changes, 'virtualNetworks', 'vd-vnet')
        assert vnet_created, "Virtual Network should be created according to what-if"
        
        # Check that NSGs would be created
        nsg_created = validate_resource_created(resource_changes, 'networkSecurityGroups', 'vd-nsg')
        assert nsg_created, "Network Security Groups should be created according to what-if"

    def test_what_if_no_unexpected_changes(self):
        """Test that what-if doesn't show unexpected resource changes."""
        # resourceGroupName extracted from params file automatically
        success, output = run_what_if(BICEP_FILE, PARAMS_FILE)
        if not success and "not logged in" in output.lower():
            pytest.skip("Azure CLI not configured - skipping what-if test")
        
        parsed = parse_what_if_output(output)
        resource_changes = parsed.get('resource_changes', [])
        
        unexpected = validate_no_unexpected_changes(resource_changes, EXPECTED_RESOURCES)
        assert len(unexpected) == 0, f"Unexpected resource changes: {unexpected}"

    def test_what_if_no_deletions(self):
        """Test that what-if doesn't show any resource deletions."""
        # resourceGroupName extracted from params file automatically
        success, output = run_what_if(BICEP_FILE, PARAMS_FILE)
        if not success and "not logged in" in output.lower():
            pytest.skip("Azure CLI not configured - skipping what-if test")
        
        parsed = parse_what_if_output(output)
        resource_changes = parsed.get('resource_changes', [])
        
        deletions = validate_no_deletions(resource_changes)
        assert len(deletions) == 0, f"Unexpected resource deletions: {deletions}"
