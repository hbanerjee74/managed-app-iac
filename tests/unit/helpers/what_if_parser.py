"""Parser for Azure what-if output to extract validation information."""
import json
from typing import Dict, List, Any, Optional


def parse_what_if_output(what_if_json: str) -> Dict[str, Any]:
    """Parse Azure what-if JSON output into structured data."""
    try:
        data = json.loads(what_if_json)
        return {
            'status': data.get('status', 'Unknown'),
            'changes': data.get('changes', []),
            'resource_changes': _extract_resource_changes(data.get('changes', [])),
            'error': data.get('error'),
            'properties': data.get('properties', {})
        }
    except json.JSONDecodeError:
        return {'error': 'Invalid JSON output', 'raw': what_if_json}


def _extract_resource_changes(changes: List[Dict]) -> List[Dict[str, Any]]:
    """Extract resource changes from what-if output."""
    resource_changes = []
    for change in changes:
        if 'resourceId' in change:
            resource_changes.append({
                'resource_id': change.get('resourceId'),
                'change_type': change.get('changeType'),  # Create, Modify, Delete, NoChange
                'delta': change.get('delta', []),
                'after': change.get('after', {}),
                'before': change.get('before', {})
            })
    return resource_changes


def validate_resource_created(resource_changes: List[Dict], resource_type: str, name_pattern: str) -> bool:
    """Check if a resource of given type would be created."""
    for change in resource_changes:
        if change.get('change_type') == 'Create':
            resource_id = change.get('resource_id', '')
            if resource_type.lower() in resource_id.lower():
                if name_pattern in resource_id:
                    return True
    return False


def validate_no_unexpected_changes(resource_changes: List[Dict], expected_resources: List[str]) -> List[str]:
    """Check for unexpected resource changes."""
    unexpected = []
    for change in resource_changes:
        resource_id = change.get('resource_id', '')
        change_type = change.get('change_type')
        
        # Check if this resource was expected
        is_expected = any(expected in resource_id for expected in expected_resources)
        
        if not is_expected and change_type in ['Create', 'Modify', 'Delete']:
            unexpected.append(f"{change_type}: {resource_id}")
    
    return unexpected


def validate_no_deletions(resource_changes: List[Dict]) -> List[str]:
    """Check for any resource deletions."""
    deletions = []
    for change in resource_changes:
        if change.get('change_type') == 'Delete':
            deletions.append(change.get('resource_id', 'Unknown'))
    return deletions

