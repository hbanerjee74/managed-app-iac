"""Utility functions for Bicep module tests."""
import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Any

# Shared params file - single source of truth for RG name and location
# Path: tests/unit/helpers/test_utils.py -> tests/unit/helpers -> tests/unit -> tests -> tests/fixtures
TESTS_DIR = Path(__file__).parent.parent.parent  # tests/
SHARED_PARAMS_FILE = TESTS_DIR / 'fixtures' / 'params.dev.json'


def ensure_resource_group_exists(rg_name: str, location: str = 'eastus') -> tuple[bool, str]:
    """Ensure resource group exists, creating it if necessary.
    
    Args:
        rg_name: Name of the resource group
        location: Azure region (default: eastus)
    
    Returns:
        Tuple of (success: bool, message: str)
    """
    try:
        # Check if RG exists
        check_result = subprocess.run(
            ['az', 'group', 'exists', '--name', rg_name],
            capture_output=True,
            text=True,
            check=False
        )
        
        if check_result.stdout.strip().lower() == 'true':
            return True, f"Resource group {rg_name} already exists"
        
        # Create RG if it doesn't exist
        print(f"Resource group {rg_name} does not exist. Creating...")
        create_result = subprocess.run(
            ['az', 'group', 'create', '--name', rg_name, '--location', location],
            capture_output=True,
            text=True,
            check=True
        )
        return True, f"Resource group {rg_name} created successfully"
        
    except subprocess.CalledProcessError as e:
        return False, f"Failed to create resource group: {e.stderr}"
    except FileNotFoundError:
        return False, "Azure CLI not found. Please install Azure CLI."


def run_bicep_build(bicep_file: Path) -> tuple[bool, str]:
    """Compile a Bicep file and return success status and output."""
    try:
        result = subprocess.run(
            ['az', 'bicep', 'build', '--file', str(bicep_file), '--stdout'],
            capture_output=True,
            text=True,
            check=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr
    except FileNotFoundError:
        return False, "Azure CLI not found. Please install Azure CLI."


def run_bicep_build_with_params(bicep_file: Path, params_file: Path, resource_group: str = None) -> tuple[bool, str]:
    """Validate a Bicep file with parameters using what-if mode.
    
    Uses 'az deployment group what-if' to validate the template with parameters.
    What-if mode evaluates template logic (including cidrSubnet calculations) which
    catches errors that 'validate' mode might miss.
    
    Args:
        bicep_file: Path to Bicep template file
        params_file: Path to parameters JSON file
        resource_group: Resource group name (extracted from shared params if None)
    
    Returns:
        Tuple of (success: bool, output: str)
    """
    if resource_group is None:
        resource_group = get_resource_group_from_shared_params()
    
    # Ensure resource group exists for what-if
    location = get_location_from_shared_params()
    rg_success, _ = ensure_resource_group_exists(resource_group, location)
    if not rg_success:
        return False, f"Failed to ensure resource group exists: {resource_group}"
    
    try:
        result = subprocess.run(
            [
                'az', 'deployment', 'group', 'what-if',
                '--resource-group', resource_group,
                '--template-file', str(bicep_file),
                '--parameters', f'@{params_file}',
                '--no-pretty-print'
            ],
            capture_output=True,
            text=True,
            check=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr
    except FileNotFoundError:
        return False, "Azure CLI not found. Please install Azure CLI."


def get_resource_group_from_shared_params() -> str:
    """Extract resource group name from shared params.dev.json file.
    
    Returns:
        Resource group name string
    
    Raises:
        ValueError: If resource group name not found
    """
    try:
        params_data = load_json_file(SHARED_PARAMS_FILE)
        # Try metadata first (new approach - ARM-provided context)
        rg_name = params_data.get('metadata', {}).get('resourceGroupName', '')
        if rg_name:
            return rg_name
        # Fallback to parameters (backward compatibility)
        rg_name = params_data.get('parameters', {}).get('resourceGroupName', {}).get('value', '')
        if rg_name:
            return rg_name
    except Exception as e:
        pass
    
    raise ValueError(f"Resource group name not found in {SHARED_PARAMS_FILE}")


def get_location_from_shared_params() -> str:
    """Extract location from shared params.dev.json file.
    
    Returns:
        Location string (defaults to 'eastus' if not found)
    """
    try:
        params_data = load_json_file(SHARED_PARAMS_FILE)
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
    return 'eastus'  # Default fallback


def get_subscription_id_from_shared_params() -> str:
    """Extract subscription ID from shared params.dev.json file.
    
    Returns:
        Subscription ID string
    
    Raises:
        ValueError: If subscription ID not found
    """
    try:
        params_data = load_json_file(SHARED_PARAMS_FILE)
        # Try metadata first (new approach - ARM-provided context)
        subscription_id = params_data.get('metadata', {}).get('subscriptionId', '')
        if subscription_id:
            return subscription_id
        # Fallback to parameters (backward compatibility)
        subscription_id = params_data.get('parameters', {}).get('subscriptionId', {}).get('value', '')
        if subscription_id:
            return subscription_id
    except Exception as e:
        pass
    
    raise ValueError(f"Subscription ID not found in {SHARED_PARAMS_FILE}")


def run_what_if(
    bicep_file: Path,
    params_file: Path,
    resource_group: str = None,  # Auto-extracted from shared params if None
    ensure_rg_exists: bool = True  # Auto-create RG if it doesn't exist
) -> tuple[bool, str]:
    """Run Azure what-if for a Bicep deployment.
    
    Args:
        bicep_file: Path to Bicep template file
        params_file: Path to parameters JSON file (for module-specific params)
        resource_group: Name of the resource group (extracted from shared params.dev.json if None)
        ensure_rg_exists: If True, create RG if it doesn't exist (location from shared params)
    
    Returns:
        Tuple of (success: bool, output: str)
        Returns JSON output with full resource payloads for parsing and validation.
        Note: resourceGroupName and location are always read from tests/fixtures/params.dev.json
        and merged into the module-specific params file before deployment.
    """
    # Extract resource group name from shared params file if not provided
    if resource_group is None:
        try:
            resource_group = get_resource_group_from_shared_params()
        except ValueError as e:
            return False, str(e)
    
    # Extract location from shared params file
    location = get_location_from_shared_params()
    
    # Ensure resource group exists if requested
    if ensure_rg_exists:
        rg_success, rg_message = ensure_resource_group_exists(resource_group, location)
        if not rg_success:
            return False, f"Resource group check failed: {rg_message}"
    
    # Load module-specific params and merge with shared resourceGroupName and location
    module_params = load_json_file(params_file)
    if 'parameters' not in module_params:
        module_params['parameters'] = {}
    
    # Merge resourceGroupName from shared params (always required)
    module_params['parameters']['resourceGroupName'] = {'value': resource_group}
    
    # Check if Bicep template requires location parameter
    bicep_content = bicep_file.read_text()
    requires_location = 'param location' in bicep_content or '@description(\'Azure region' in bicep_content
    
    # Only add location if the template requires it
    if requires_location:
        module_params['parameters']['location'] = {'value': location}
    
    # Check if Bicep template requires subscriptionId parameter (for gateway test wrapper)
    requires_subscription_id = 'param subscriptionId' in bicep_content
    
    # Only add subscriptionId if the template requires it
    if requires_subscription_id:
        try:
            subscription_id = get_subscription_id_from_shared_params()
            module_params['parameters']['subscriptionId'] = {'value': subscription_id}
        except ValueError:
            # If subscription ID not found, skip adding it (will fail with clear error)
            pass
    
    # Create temporary merged params file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_file:
        json.dump(module_params, tmp_file, indent=2)
        tmp_params_file = tmp_file.name
    
    try:
        result = subprocess.run(
            [
                'az', 'deployment', 'group', 'what-if',
                '--resource-group', resource_group,
                '--template-file', str(bicep_file),
                '--parameters', f'@{tmp_params_file}',
                '--output', 'json',
                '--result-format', 'FullResourcePayloads',
                '--no-pretty-print'
            ],
            capture_output=True,
            text=True,
            check=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr
    except FileNotFoundError:
        return False, "Azure CLI not found. Please install Azure CLI."
    finally:
        # Clean up temporary file
        try:
            os.unlink(tmp_params_file)
        except Exception:
            pass


def load_json_file(file_path: Path) -> Dict[str, Any]:
    """Load and parse a JSON file."""
    with open(file_path, 'r') as f:
        return json.load(f)


def validate_required_params(params: Dict[str, Any], required: list[str]) -> tuple[bool, list[str]]:
    """Validate that all required parameters are present."""
    missing = [p for p in required if p not in params.get('parameters', {})]
    return len(missing) == 0, missing

