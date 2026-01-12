"""End-to-end tests for main.bicep (full-scope deployment)."""
import os
import json
import pytest
import subprocess
import tempfile
from pathlib import Path

# Summarize what-if changes helper function
def summarize(changes):
    """Summarize what-if changes by change type."""
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
DEPLOYMENT_OUTPUT = Path(__file__).parent / 'deployment-output.json'
DEPLOYMENT_ERROR_LOG = Path(__file__).parent / 'deployment-error.log'

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


def get_merged_params_file():
    """Create a merged params file with metadata values injected into parameters.
    
    Merges metadata values (like isManagedApplication) into the parameters section
    so they can be passed to Bicep templates via Azure CLI.
    
    Returns:
        Path to temporary merged params file (caller should clean up)
    """
    params_data = json.loads(PARAMS_FILE.read_text())
    
    # Start with existing parameters
    merged_params = {
        '$schema': params_data.get('$schema', ''),
        'contentVersion': params_data.get('contentVersion', '1.0.0.0'),
        'parameters': params_data.get('parameters', {}).copy()
    }
    
    # Merge metadata values into parameters (for Bicep consumption)
    metadata = params_data.get('metadata', {})
    
    # Merge isManagedApplication from metadata into parameters
    if 'isManagedApplication' in metadata and 'isManagedApplication' not in merged_params['parameters']:
        merged_params['parameters']['isManagedApplication'] = {'value': metadata['isManagedApplication']}
    
    # Create temporary file with merged params
    tmp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
    json.dump(merged_params, tmp_file, indent=2)
    tmp_file.close()
    
    return Path(tmp_file.name)


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


def ensure_resource_group(rg_name: str, location: str):
    """Ensure resource group exists, creating if needed.
    
    If resource group exists, deployment will update existing resources.
    If resource group doesn't exist, it will be created.
    
    Args:
        rg_name: Name of the resource group
        location: Azure region
    
    Returns:
        str: Resource group name
    """
    # Check if RG exists
    check_result = subprocess.run(
        ['az', 'group', 'exists', '--name', rg_name],
        capture_output=True,
        text=True,
        check=False
    )
    
    if check_result.stdout.strip().lower() == 'true':
        # Resource group exists - use it (deployment will update resources)
        print(f"✓ Resource group '{rg_name}' already exists. Deployment will update existing resources.")
        return rg_name
    
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
    
    print(f"✓ Resource group {rg_name} created successfully")
    return rg_name


@pytest.fixture(scope="function", autouse=True)
def setup_azure_context():
    """Automatically set Azure subscription from params file if provided.
    
    Runs before each test to ensure correct subscription is active.
    This allows tests to be self-contained after az login.
    """
    ensure_subscription_set()


@pytest.fixture(scope="function")
def test_resource_group():
    """Ensure test resource group exists before each test.
    
    Creates resource group if it doesn't exist, or reuses if it does.
    Resource group is NOT deleted after test - next run will update resources.
    
    Only creates when ENABLE_ACTUAL_DEPLOYMENT=true.
    For what-if tests, uses existing RG from params file.
    
    Yields:
        str: Resource group name
    """
    rg_name = get_resource_group_from_params()
    
    if not ENABLE_ACTUAL_DEPLOYMENT:
        # For what-if tests, just yield RG name from params (no creation)
        yield rg_name
    else:
        # For actual deployment tests, ensure RG exists
        location = get_location_from_params()
        ensure_resource_group(rg_name, location)
        yield rg_name
        # No cleanup - resource group persists for next test run


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
            merged_params_file = get_merged_params_file()
            try:
                result = subprocess.run(
                    [
                        'az', 'deployment', 'group', 'what-if',
                        '--resource-group', rg_name,
                        '--template-file', str(MAIN_BICEP),
                        '--parameters', f'@{merged_params_file}',
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
            finally:
                # Clean up temporary merged params file
                if merged_params_file.exists():
                    merged_params_file.unlink()
            
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
        """Test that what-if summary can be generated."""
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
        """Test actual deployment and post-deployment state check (opt-in only).
        
        This test:
        1. Deploys main.bicep to create/update real resources
        2. Runs what-if to validate deployed state (no unexpected deletions)
        
        Note: Resource group persists after test - next run will update existing resources.
        """
        # Step 1: Deploy resources
        merged_params_file = get_merged_params_file()
        deployment_data = None
        try:
            try:
                deploy_result = subprocess.run(
                    [
                        'az', 'deployment', 'group', 'create',
                        '--resource-group', test_resource_group,
                        '--template-file', str(MAIN_BICEP),
                        '--parameters', f'@{merged_params_file}',
                        '--mode', 'Complete',
                        '--output', 'json'
                    ],
                    capture_output=True,
                    text=True,
                    check=True
                )
                
                # Save deployment output to file for debugging
                DEPLOYMENT_OUTPUT.write_text(deploy_result.stdout)
                if deploy_result.stderr:
                    DEPLOYMENT_ERROR_LOG.write_text(deploy_result.stderr)
                
                # Parse deployment output to check for errors even if returncode is 0
                try:
                    deployment_data = json.loads(deploy_result.stdout)
                    if 'error' in deployment_data:
                        error_msg = json.dumps(deployment_data['error'], indent=2)
                        DEPLOYMENT_ERROR_LOG.write_text(f"Deployment contains errors:\n{error_msg}")
                        pytest.fail(f"Deployment contains errors. Check {DEPLOYMENT_ERROR_LOG} for details:\n{error_msg}")
                    
                    # Log deployment properties for debugging
                    props = deployment_data.get('properties', {})
                    provisioning_state = props.get('provisioningState', 'Unknown')
                    if provisioning_state not in ['Succeeded', 'Accepted']:
                        error_msg = f"Deployment provisioning state: {provisioning_state}"
                        if 'error' in props:
                            error_msg += f"\nError: {json.dumps(props['error'], indent=2)}"
                        DEPLOYMENT_ERROR_LOG.write_text(error_msg)
                        pytest.fail(f"Deployment did not succeed. State: {provisioning_state}. Check {DEPLOYMENT_ERROR_LOG} for details.")
                except json.JSONDecodeError:
                    # Not JSON, that's okay - might be a warning or other output
                    pass
                
                assert deploy_result.returncode == 0, "Deployment failed"
            finally:
                # Clean up temporary merged params file
                if merged_params_file.exists():
                    merged_params_file.unlink()
            
            # Get deployment name for operations check
            if deployment_data is None:
                try:
                    deployment_data = json.loads(DEPLOYMENT_OUTPUT.read_text())
                except Exception:
                    pass
            
            if deployment_data:
                try:
                    deployment_name = deployment_data.get('name', '')
                    if deployment_name:
                        # Check for failed operations
                        ops_result = subprocess.run(
                            [
                                'az', 'deployment', 'operation', 'group', 'list',
                                '--resource-group', test_resource_group,
                                '--name', deployment_name,
                                '--output', 'json'
                            ],
                            capture_output=True,
                            text=True,
                            check=False
                        )
                        if ops_result.returncode == 0:
                            try:
                                operations = json.loads(ops_result.stdout)
                                failed_ops = [
                                    op for op in operations
                                    if op.get('properties', {}).get('provisioningState') == 'Failed'
                                ]
                                if failed_ops:
                                    failed_summary = []
                                    for op in failed_ops:
                                        op_name = op.get('operationId', 'Unknown')
                                        error = op.get('properties', {}).get('statusMessage', {})
                                        failed_summary.append(f"  - {op_name}: {json.dumps(error, indent=4)}")
                                    
                                    failed_msg = "Failed deployment operations:\n" + "\n".join(failed_summary)
                                    DEPLOYMENT_ERROR_LOG.write_text(
                                        DEPLOYMENT_ERROR_LOG.read_text() + "\n\n" + failed_msg
                                        if DEPLOYMENT_ERROR_LOG.exists() else failed_msg
                                    )
                                    pytest.fail(f"Deployment completed but some operations failed. Check {DEPLOYMENT_ERROR_LOG} for details:\n{failed_msg}")
                            except json.JSONDecodeError:
                                pass  # Couldn't parse operations, that's okay
                except Exception:
                    pass  # Couldn't get deployment name, that's okay
            
        except subprocess.CalledProcessError as e:
            # Save error output to files for debugging
            if e.stdout:
                DEPLOYMENT_OUTPUT.write_text(e.stdout)
            if e.stderr:
                DEPLOYMENT_ERROR_LOG.write_text(f"Deployment command failed:\n{e.stderr}")
            pytest.fail(f"Actual deployment failed. Check {DEPLOYMENT_ERROR_LOG} for details:\n{e.stderr}")
        except FileNotFoundError:
            pytest.skip("Azure CLI not found")
        
        # Step 2: Post-deployment state check (before fixture tears down RG)
        # Run what-if against deployed resources to validate state
        merged_params_file = get_merged_params_file()
        try:
            try:
                what_if_result = subprocess.run(
                    [
                        'az', 'deployment', 'group', 'what-if',
                        '--resource-group', test_resource_group,
                        '--template-file', str(MAIN_BICEP),
                        '--parameters', f'@{merged_params_file}',
                        '--output', 'json',
                        '--result-format', 'FullResourcePayloads',
                        '--no-pretty-print'
                    ],
                    capture_output=True,
                    text=True,
                    check=True
                )
            finally:
                # Clean up temporary merged params file
                if merged_params_file.exists():
                    merged_params_file.unlink()
            
            # Parse and validate what-if output
            what_if_data = json.loads(what_if_result.stdout)
            changes = what_if_data.get('changes', [])
            summary = summarize(changes)
            
            # After deployment, we expect mostly NoChange (or some Modify for idempotency)
            # Unexpected Creates or Deletes indicate drift
            unexpected_deletes = summary.get('Delete', 0)
            
            # Allow some Creates/Modifies for idempotency, but no Deletes
            assert unexpected_deletes == 0, (
                f"Unexpected resource deletions detected after deployment: {summary}. "
                f"This indicates drift between template and deployed state."
            )
            
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Post-deployment what-if failed: {e.stderr}")
        except FileNotFoundError:
            pytest.skip("Azure CLI not found")
