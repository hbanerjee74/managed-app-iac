"""Utility functions for Bicep module tests."""
import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, Any, Optional


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


def run_what_if(
    bicep_file: Path,
    params_file: Path,
    resource_group: str,
    location: str = 'eastus'  # Not used for RG deployments, kept for API compatibility
) -> tuple[bool, str]:
    """Run Azure what-if for a Bicep deployment.
    
    Returns JSON output with full resource payloads for parsing and validation.
    Note: --location is not used for resource group-scoped deployments.
    """
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

