"""Utility functions for Bicep module tests."""
import json
import subprocess
from pathlib import Path
from typing import Dict, Any

# Shared params file - single source of truth for RG name and location
SHARED_PARAMS_FILE = Path(__file__).parent.parent.parent / 'tests' / 'fixtures' / 'params.dev.json'


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
        Module-specific params file is only used for --parameters flag.
    """
    # Extract resource group name from shared params file if not provided
    if resource_group is None:
        try:
            resource_group = get_resource_group_from_shared_params()
        except ValueError as e:
            return False, str(e)
    
    # Extract location from shared params file for RG creation if needed
    location = get_location_from_shared_params()
    
    # Ensure resource group exists if requested
    if ensure_rg_exists:
        rg_success, rg_message = ensure_resource_group_exists(resource_group, location)
        if not rg_success:
            return False, f"Resource group check failed: {rg_message}"
    
    try:
        result = subprocess.run(
            [
                'az', 'deployment', 'group', 'what-if',
                '--resource-group', resource_group,
                '--template-file', str(bicep_file),
                '--parameters', f'@{params_file}',
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


def load_json_file(file_path: Path) -> Dict[str, Any]:
    """Load and parse a JSON file."""
    with open(file_path, 'r') as f:
        return json.load(f)


def validate_required_params(params: Dict[str, Any], required: list[str]) -> tuple[bool, list[str]]:
    """Validate that all required parameters are present."""
    missing = [p for p in required if p not in params.get('parameters', {})]
    return len(missing) == 0, missing


def get_module_outputs(module_name: str) -> Dict[str, Any]:
    """Get expected module outputs structure for mocking."""
    # This will be populated based on actual module outputs
    outputs = {
        'diagnostics': {
            'lawId': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law',
            'lawWorkspaceId': '00000000-0000-0000-0000-000000000000'
        },
        'identity': {
            'uamiPrincipalId': '00000000-0000-0000-0000-000000000000',
            'uamiClientId': '00000000-0000-0000-0000-000000000000',
            'uamiId': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-uami'
        },
        'network': {
            'subnetPsqlId': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-psql',
            'subnetAppsvcId': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-appsvc',
            'subnetPeId': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-pe',
            'subnetAppgwId': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/snet-appgw'
        },
        'dns': {
            'zoneIds': {
                'vault': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net',
                'postgres': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com',
                'blob': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net',
                'queue': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net',
                'table': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net',
                'acr': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io',
                'appsvc': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net',
                'search': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net',
                'ai': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com',
                'automation': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net',
                'internal': '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/vibedata.internal'
            }
        }
    }
    return outputs.get(module_name, {})
