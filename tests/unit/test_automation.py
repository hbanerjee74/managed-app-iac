"""Unit tests for automation module."""
import pytest
from pathlib import Path
from tests.unit.helpers.test_utils import (
    run_bicep_build,
    run_what_if,
    load_json_file
)


FIXTURES_DIR = Path(__file__).parent / 'fixtures'
BICEP_FILE = FIXTURES_DIR / 'test-automation.bicep'
PARAMS_FILE = FIXTURES_DIR / 'params-automation.json'
TEST_RG = 'test-rg'


class TestAutomationModule:
    """Test suite for automation module."""

    def test_bicep_compiles(self):
        """Test that the automation test wrapper compiles successfully."""
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
        """Test that what-if execution succeeds."""
        success, output = run_what_if(BICEP_FILE, PARAMS_FILE, TEST_RG)
        if not success and "not logged in" in output.lower():
            pytest.skip("Azure CLI not configured - skipping what-if test")
        assert success, f"What-if failed: {output}"

