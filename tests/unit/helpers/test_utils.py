"""Utility functions for Bicep module tests."""
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Any, Set

# Shared params file - single source of truth for RG name and location
# Path: tests/unit/helpers/test_utils.py -> tests/unit/helpers -> tests/unit -> tests -> tests/fixtures
TESTS_DIR = Path(__file__).parent.parent.parent  # tests/
SHARED_PARAMS_FILE = TESTS_DIR / 'fixtures' / 'params.dev.json'


def extract_bicep_parameters(bicep_file: Path) -> Set[str]:
    """Extract parameter names declared in a Bicep template.
    
    Args:
        bicep_file: Path to Bicep template file
        
    Returns:
        Set of parameter names declared in the template
    """
    try:
        content = bicep_file.read_text()
        # Match 'param <name>' declarations (handles various formats)
        # Pattern matches: param name, param name string, param name int, etc.
        pattern = r'param\s+(\w+)\s+'
        matches = re.findall(pattern, content)
        return set(matches)
    except Exception:
        # If we can't parse, return empty set (will include all params - may fail but that's ok)
        return set()


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
    params_file: Path = None,  # Optional - if None, uses only shared params
    resource_group: str = None,  # Auto-extracted from shared params if None
    ensure_rg_exists: bool = True  # Auto-create RG if it doesn't exist
) -> tuple[bool, str]:
    """Run Azure what-if for a Bicep deployment.
    
    Args:
        bicep_file: Path to Bicep template file
        params_file: Optional path to parameters JSON file (for module-specific overrides)
        resource_group: Name of the resource group (extracted from shared params.dev.json if None)
        ensure_rg_exists: If True, create RG if it doesn't exist (location from shared params)
    
    Returns:
        Tuple of (success: bool, output: str)
        Returns JSON output with full resource payloads for parsing and validation.
        
    Note:
        All parameters from tests/fixtures/params.dev.json are automatically included.
        If params_file is provided, its parameters override shared params.
        resourceGroupName and location are always set from metadata section.
        Bicep will ignore any unused parameters, so it's safe to include all parameters.
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
    
    # Initialize module params (empty if no params_file provided)
    module_params = {'parameters': {}}
    if params_file is not None:
        module_params = load_json_file(params_file)
        if 'parameters' not in module_params:
            module_params['parameters'] = {}
    
    # Extract parameters actually declared in the Bicep template
    declared_params = extract_bicep_parameters(bicep_file)
    
    # Load shared params file (single source of truth)
    shared_params = load_json_file(SHARED_PARAMS_FILE)
    
    # Merge parameters from shared params, but only include those declared in the template
    # (Azure ARM rejects extra parameters)
    shared_param_values = shared_params.get('parameters', {})
    for param_name, param_value in shared_param_values.items():
        # Only add if:
        # 1. Not already in module params (module params take precedence)
        # 2. Parameter is declared in the Bicep template (to avoid ARM validation errors)
        if param_name not in module_params['parameters'] and param_name in declared_params:
            module_params['parameters'][param_name] = param_value
    
    # Always merge resourceGroupName and location from metadata (these are special)
    # These come from metadata section, not parameters section
    # Only add if declared in template
    if 'resourceGroupName' in declared_params:
        module_params['parameters']['resourceGroupName'] = {'value': resource_group}
    if 'location' in declared_params:
        module_params['parameters']['location'] = {'value': location}
    
    # Handle subscriptionId from metadata if available (for gateway test wrapper)
    # Only add if declared in template
    if 'subscriptionId' in declared_params and 'subscriptionId' not in module_params['parameters']:
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
        # Filter out warnings from output (Azure CLI writes warnings to stderr, but they may be mixed)
        # Warnings typically start with "WARNING:" and are not part of JSON output
        # Also handle multi-line warnings and find the actual JSON content
        output = result.stdout
        
        # Remove WARNING lines (including multi-line warnings)
        lines = output.split('\n')
        json_lines = []
        skip_until_empty = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith('WARNING:'):
                skip_until_empty = True
                continue
            if skip_until_empty and not stripped:
                skip_until_empty = False
                continue
            if not skip_until_empty:
                json_lines.append(line)
        
        cleaned_output = '\n'.join(json_lines).strip()
        
        # If output is empty after filtering, return original (shouldn't happen, but safety check)
        if not cleaned_output:
            cleaned_output = output
        
        return True, cleaned_output
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
