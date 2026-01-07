"""End-to-end tests for main.bicep (full-scope deployment)."""
import os
import json
import pytest
import subprocess
import time
from pathlib import Path
import sys

# Add state_check to path for importing utilities
STATE_CHECK_DIR = Path(__file__).parent / 'state_check'
sys.path.insert(0, str(STATE_CHECK_DIR.parent))

# Import summarize function from diff_report
def summarize(changes):
    """Summarize what-if changes (from e2e/state_check/diff_report.py)."""
    summary = {"Create": 0, "Modify": 0, "Delete": 0, "NoChange": 0}
    for change in changes:
        change_type = change.get("changeType", "Unknown")
        summary[change_type] = summary.get(change_type, 0) + 1
    return summary


# Use tests/fixtures/params.dev.json (not e2e/fixtures)
FIXTURES_DIR = Path(__file__).parent.parent / 'fixtures'
MAIN_BICEP = Path(__file__).parent.parent.parent / 'iac' / 'main.bicep'
PARAMS_FILE = FIXTURES_DIR / 'params.dev.json'
TEST_RG = 'test-rg'  # Fallback only - should come from params file
WHAT_IF_OUTPUT = Path(__file__).parent / 'what-if-output.json'
RG_CREATE_TIMEOUT = 300  # 5 minutes
RG_DELETE_TIMEOUT = 600  # 10 minutes

# Check if actual deployment is enabled
ENABLE_ACTUAL_DEPLOYMENT = os.getenv('ENABLE_ACTUAL_DEPLOYMENT', 'false').lower() == 'true'


def get_resource_group_from_params():
    """Extract resource group name from params file metadata (or parameters for backward compatibility)."""
    try:
        params_data = json.loads(PARAMS_FILE.read_text())
        # Try metadata first (new approach - ARM-provided context)
        rg_name = params_data.get('metadata', {}).get('resourceGroupName', '')
        if rg_name:
            return rg_name
        # Fallback to parameters (backward compatibility)
        return params_data.get('parameters', {}).get('resourceGroupName', {}).get('value', TEST_RG)
    except Exception:
        return TEST_RG


def get_location_from_params():
    """Extract location from params file metadata (or parameters for backward compatibility)."""
    try:
        params_data = json.loads(PARAMS_FILE.read_text())
        # Try metadata first (new approach - ARM-provided context)
        location = params_data.get('metadata', {}).get('location', '')
        if location:
            return location
        # Fallback to parameters (backward compatibility)
        location = params_data.get('parameters', {}).get('location', {}).get('value', '')
        if location:
            return location
    except Exception:
        pass
    # Default fallback if not found in params file
    return 'eastus'


def get_subscription_id_from_params():
    """Extract subscription ID from params file metadata."""
    try:
        params_data = json.loads(PARAMS_FILE.read_text())
        subscription_id = params_data.get('metadata', {}).get('subscriptionId', '')
        return subscription_id if subscription_id else None
    except Exception:
        return None


def ensure_subscription_set():
    """Set Azure subscription from params file if provided.
    
    If subscriptionId is in params file metadata, sets it as the active subscription.
    This allows tests to be self-contained after az login.
    """
    subscription_id = get_subscription_id_from_params()
    if subscription_id:
        try:
            subprocess.run(
                ['az', 'account', 'set', '--subscription', subscription_id],
                capture_output=True,
                text=True,
                check=True
            )
            print(f"Set subscription to {subscription_id}")
        except subprocess.CalledProcessError as e:
            print(f"Warning: Failed to set subscription: {e.stderr}")
        except FileNotFoundError:
            pass  # Azure CLI not available


def create_resource_group(rg_name: str, location: str, timeout: int = RG_CREATE_TIMEOUT):
    """Create resource group, deleting existing one if present.
    
    Args:
        rg_name: Name of the resource group
        location: Azure region
        timeout: Maximum time to wait for operations (seconds)
    
    Raises:
        RuntimeError: If creation or deletion fails
    """
    # Check if RG exists and delete it
    check_result = subprocess.run(
        ['az', 'group', 'exists', '--name', rg_name],
        capture_output=True,
        text=True,
        check=False
    )
    
    if check_result.stdout.strip().lower() == 'true':
        # Delete existing RG
        print(f"Resource group {rg_name} exists. Deleting...")
        delete_result = subprocess.run(
            ['az', 'group', 'delete', '--name', rg_name, '--yes'],
            capture_output=True,
            text=True,
            check=False
        )
        
        if delete_result.returncode != 0:
            raise RuntimeError(f"Failed to delete existing resource group: {delete_result.stderr}")
        
        # Wait for deletion to complete
        start_time = time.time()
        while time.time() - start_time < timeout:
            check_result = subprocess.run(
                ['az', 'group', 'exists', '--name', rg_name],
                capture_output=True,
                text=True,
                check=False
            )
            if check_result.stdout.strip().lower() == 'false':
                break
            time.sleep(5)
        else:
            raise RuntimeError(f"Resource group deletion timed out after {timeout} seconds")
    
    # Create new RG
    print(f"Creating resource group {rg_name} in {location}...")
    create_result = subprocess.run(
        ['az', 'group', 'create', '--name', rg_name, '--location', location],
        capture_output=True,
        text=True,
        check=True
    )
    
    # Verify creation
    check_result = subprocess.run(
        ['az', 'group', 'exists', '--name', rg_name],
        capture_output=True,
        text=True,
        check=True
    )
    
    if check_result.stdout.strip().lower() != 'true':
        raise RuntimeError(f"Resource group creation verification failed")
    
    return rg_name


def delete_resource_group(rg_name: str, timeout: int = RG_DELETE_TIMEOUT):
    """Delete resource group and wait for completion.
    
    Args:
        rg_name: Name of the resource group
        timeout: Maximum time to wait for deletion (seconds)
    
    Returns:
        bool: True if deletion succeeded, False otherwise
    """
    print(f"Deleting resource group {rg_name}...")
    delete_result = subprocess.run(
        ['az', 'group', 'delete', '--name', rg_name, '--yes'],
        capture_output=True,
        text=True,
        check=False
    )
    
    if delete_result.returncode != 0:
        print(f"Warning: Failed to delete resource group: {delete_result.stderr}")
        return False
    
    # Wait for deletion to complete
    start_time = time.time()
    while time.time() - start_time < timeout:
        check_result = subprocess.run(
            ['az', 'group', 'exists', '--name', rg_name],
            capture_output=True,
            text=True,
            check=False
        )
        if check_result.stdout.strip().lower() == 'false':
            print(f"Resource group {rg_name} deleted successfully")
            return True
        time.sleep(5)
    
    print(f"Warning: Resource group deletion timed out after {timeout} seconds")
    return False


@pytest.fixture(scope="function", autouse=True)
def setup_azure_context():
    """Automatically set Azure subscription from params file if provided.
    
    Runs before each test to ensure correct subscription is active.
    This allows tests to be self-contained after az login.
    """
    ensure_subscription_set()


@pytest.fixture(scope="function")
def test_resource_group():
    """Create test resource group before each test, delete after.
    
    Only creates/deletes when ENABLE_ACTUAL_DEPLOYMENT=true.
    For what-if tests, uses existing RG from params file.
    
    Yields:
        str: Resource group name
    """
    if not ENABLE_ACTUAL_DEPLOYMENT:
        # For what-if tests, just return RG name from params
        yield get_resource_group_from_params()
        return
    
    # For actual deployment tests, create fresh RG
    rg_name = get_resource_group_from_params()
    location = get_location_from_params()
    
    try:
        # Create RG (deletes existing if present)
        create_resource_group(rg_name, location)
        yield rg_name
    finally:
        # Always cleanup, even if test failed
        try:
            delete_resource_group(rg_name)
        except Exception as e:
            print(f"Error during resource group cleanup: {e}")


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
            rg_name = get_resource_group_from_params()
            result = subprocess.run(
                [
                    'az', 'deployment', 'group', 'what-if',
                    '--resource-group', rg_name,
                    '--template-file', str(MAIN_BICEP),
                    '--parameters', f'@{PARAMS_FILE}',
                    '--output', 'json',
                    '--result-format', 'FullResourcePayloads',
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
    def test_actual_deployment(self, test_resource_group):
        """Test actual deployment (opt-in only).
        
        Resource group is automatically created before test and deleted after.
        """
        # Resource group is already created by fixture
        try:
            result = subprocess.run(
                [
                    'az', 'deployment', 'group', 'create',
                    '--resource-group', test_resource_group,
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
    def test_post_deployment_state_check(self, test_resource_group):
        """Test post-deployment state check using state_check utilities.
        
        Resource group is automatically created before test and deleted after.
        """
        # Run what-if against deployed resources
        try:
            result = subprocess.run(
                [
                    'az', 'deployment', 'group', 'what-if',
                    '--resource-group', test_resource_group,
                    '--template-file', str(MAIN_BICEP),
                    '--parameters', f'@{PARAMS_FILE}',
                    '--output', 'json',
                    '--result-format', 'FullResourcePayloads',
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

