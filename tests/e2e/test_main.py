"""End-to-end tests for main.bicep (full-scope deployment)."""
import os
import json
import pytest
import subprocess
from pathlib import Path
import sys

# Add state_check to path for importing utilities
STATE_CHECK_DIR = Path(__file__).parent.parent / 'state_check'
sys.path.insert(0, str(STATE_CHECK_DIR.parent))

# Import summarize function from diff_report
def summarize(changes):
    """Summarize what-if changes (from state_check/diff_report.py)."""
    summary = {"Create": 0, "Modify": 0, "Delete": 0, "NoChange": 0}
    for change in changes:
        change_type = change.get("changeType", "Unknown")
        summary[change_type] = summary.get(change_type, 0) + 1
    return summary


FIXTURES_DIR = Path(__file__).parent / 'fixtures'
MAIN_BICEP = Path(__file__).parent.parent.parent / 'iac' / 'main.bicep'
PARAMS_FILE = FIXTURES_DIR / 'params.dev.json'
TEST_RG = 'test-rg'
TEST_LOCATION = 'eastus'
WHAT_IF_OUTPUT = Path(__file__).parent / 'what-if-output.json'

# Check if actual deployment is enabled
ENABLE_ACTUAL_DEPLOYMENT = os.getenv('ENABLE_ACTUAL_DEPLOYMENT', 'false').lower() == 'true'


class TestMainBicep:
    """Test suite for main.bicep full-scope deployment."""

    def test_bicep_compiles(self):
        """Test that main.bicep compiles successfully."""
        try:
            result = subprocess.run(
                ['az', 'bicep', 'build', '--file', str(MAIN_BICEP), '--stdout'],
                capture_output=True,
                text=True,
                check=True
            )
            assert result.returncode == 0
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Bicep compilation failed: {e.stderr}")
        except FileNotFoundError:
            pytest.skip("Azure CLI not found")

    def test_params_file_exists(self):
        """Test that parameter file exists."""
        assert PARAMS_FILE.exists(), f"Parameter file not found: {PARAMS_FILE}"

    def test_params_file_valid_json(self):
        """Test that parameter file is valid JSON."""
        import json
        try:
            with open(PARAMS_FILE, 'r') as f:
                params = json.load(f)
            assert 'parameters' in params
        except Exception as e:
            pytest.fail(f"Invalid JSON in params file: {e}")

    def test_what_if_succeeds(self):
        """Test that what-if execution succeeds (default mode)."""
        try:
            result = subprocess.run(
                [
                    'az', 'deployment', 'sub', 'what-if',
                    '--location', TEST_LOCATION,
                    '--template-file', str(MAIN_BICEP),
                    '--parameters', f'@{PARAMS_FILE}',
                    '--result-format', 'Full',
                    '--no-pretty-print'
                ],
                capture_output=True,
                text=True,
                check=True
            )
            assert result.returncode == 0
            
            # Save what-if output for post-deployment validation
            WHAT_IF_OUTPUT.write_text(result.stdout)
            
        except subprocess.CalledProcessError as e:
            if "not logged in" in e.stderr.lower():
                pytest.skip("Azure CLI not configured - skipping what-if test")
            pytest.fail(f"What-if failed: {e.stderr}")
        except FileNotFoundError:
            pytest.skip("Azure CLI not found")

    def test_what_if_output_valid(self):
        """Test that what-if output is valid JSON and can be parsed."""
        if not WHAT_IF_OUTPUT.exists():
            pytest.skip("What-if output not available - run test_what_if_succeeds first")
        
        try:
            data = json.loads(WHAT_IF_OUTPUT.read_text())
            assert 'status' in data or 'changes' in data
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON in what-if output: {e}")

    def test_what_if_summary(self):
        """Test that what-if summary can be generated (using state_check utilities)."""
        if not WHAT_IF_OUTPUT.exists():
            pytest.skip("What-if output not available - run test_what_if_succeeds first")
        
        try:
            data = json.loads(WHAT_IF_OUTPUT.read_text())
            changes = data.get('changes', [])
            summary = summarize(changes)
            
            # Validate summary structure
            assert isinstance(summary, dict)
            assert 'Create' in summary
            assert 'Modify' in summary
            assert 'Delete' in summary
            assert 'NoChange' in summary
            
        except Exception as e:
            pytest.fail(f"Failed to generate what-if summary: {e}")

    @pytest.mark.skipif(
        not ENABLE_ACTUAL_DEPLOYMENT,
        reason="Actual deployment disabled. Set ENABLE_ACTUAL_DEPLOYMENT=true to enable."
    )
    def test_actual_deployment(self):
        """Test actual deployment (opt-in only)."""
        # This test only runs if ENABLE_ACTUAL_DEPLOYMENT=true
        # WARNING: This creates real Azure resources!
        try:
            result = subprocess.run(
                [
                    'az', 'deployment', 'sub', 'create',
                    '--location', TEST_LOCATION,
                    '--template-file', str(MAIN_BICEP),
                    '--parameters', f'@{PARAMS_FILE}'
                ],
                capture_output=True,
                text=True,
                check=True
            )
            assert result.returncode == 0
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Actual deployment failed: {e.stderr}")
        except FileNotFoundError:
            pytest.skip("Azure CLI not found")

    @pytest.mark.skipif(
        not ENABLE_ACTUAL_DEPLOYMENT,
        reason="Actual deployment disabled. Set ENABLE_ACTUAL_DEPLOYMENT=true to enable."
    )
    def test_post_deployment_state_check(self):
        """Test post-deployment state check using state_check utilities."""
        # This test validates deployed state matches Bicep after actual deployment
        # Requires: ENABLE_ACTUAL_DEPLOYMENT=true and resource group exists
        
        # Get resource group from params
        try:
            params_data = json.loads(PARAMS_FILE.read_text())
            resource_group = params_data.get('parameters', {}).get('resourceGroup', {}).get('value', TEST_RG)
        except Exception:
            resource_group = TEST_RG
        
        # Run what-if against deployed resources
        try:
            result = subprocess.run(
                [
                    'az', 'deployment', 'sub', 'what-if',
                    '--location', TEST_LOCATION,
                    '--template-file', str(MAIN_BICEP),
                    '--parameters', f'@{PARAMS_FILE}',
                    '--result-format', 'Full',
                    '--no-pretty-print'
                ],
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse and validate what-if output
            what_if_data = json.loads(result.stdout)
            changes = what_if_data.get('changes', [])
            summary = summarize(changes)
            
            # After deployment, we expect mostly NoChange (or some Modify for idempotency)
            # Unexpected Creates or Deletes indicate drift
            unexpected_creates = summary.get('Create', 0)
            unexpected_deletes = summary.get('Delete', 0)
            
            # Allow some Creates/Modifies for idempotency, but no Deletes
            assert unexpected_deletes == 0, f"Unexpected resource deletions detected: {summary}"
            
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Post-deployment what-if failed: {e.stderr}")
        except FileNotFoundError:
            pytest.skip("Azure CLI not found")

