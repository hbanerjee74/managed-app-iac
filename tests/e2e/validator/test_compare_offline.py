import json
from pathlib import Path

import pytest

from tests.e2e.validator.compare_expectation import ANY_VALUE, compare_expected_actual


def _write(tmp_path: Path, name: str, data: dict) -> Path:
    path = tmp_path / name
    path.write_text(json.dumps(data, indent=2))
    return path


def test_compare_matches_placeholders(tmp_path: Path):
    expected = {
        "resourceGroup": "rg-dev",
        "location": "eastus",
        "tags": {"env": "dev"},
        "names": {"vnet": "vd-vnet-platform-<16>"},
        "resources": [
            {
                "type": "Microsoft.Network/virtualNetworks",
                "name": "vd-vnet-platform-<16>",
                "properties": {
                    "addressSpace": {"addressPrefixes": ["10.0.0.0/24"]},
                    "subnets": {"snet-app": "10.0.0.0/26"},
                    "subnetsDetailed": [
                        {
                            "name": "snet-app",
                            "addressPrefix": "10.0.0.0/26",
                            "networkSecurityGroupId": ANY_VALUE,
                        }
                    ],
                },
            },
            {
                "type": "Microsoft.ManagedIdentity/userAssignedIdentities",
                "name": "vd-uami-platform-<16>",
                "properties": {
                    "clientId": "<guid>",
                    "principalId": "<guid>",
                },
            },
            {
                "type": "Microsoft.Insights/diagnosticSettings",
                "name": "diag-law-kv",
                "scopeType": "Microsoft.KeyVault/vaults",
                "scopeName": "vd-kv-platform-<16>",
                "properties": {
                    "workspaceId": ANY_VALUE,
                    "logs": [{"category": "AuditEvent", "enabled": True}],
                    "metrics": [{"category": "AllMetrics", "enabled": True}],
                },
            },
        ],
    }

    actual = {
        "resourceGroup": "rg-dev",
        "location": "eastus",
        "tags": {"env": "dev"},
        "names": {"vnet": "vd-vnet-platform-1234567890abcdef"},
        "resources": [
            {
                "type": "Microsoft.Network/virtualNetworks",
                "name": "vd-vnet-platform-1234567890abcdef",
                "properties": {
                    "addressSpace": {"addressPrefixes": ["10.0.0.0/24"]},
                    "subnets": {"snet-app": "10.0.0.0/26"},
                    "subnetsDetailed": [
                        {
                            "name": "snet-app",
                            "addressPrefix": "10.0.0.0/26",
                            "networkSecurityGroupId": "/subs/abc/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg",
                        }
                    ],
                },
            },
            {
                "type": "Microsoft.ManagedIdentity/userAssignedIdentities",
                "name": "vd-uami-platform-aaaaaaaaaaaaaaaa",
                "properties": {
                    "clientId": "00000000-0000-0000-0000-000000000000",
                    "principalId": "11111111-1111-1111-1111-111111111111",
                },
            },
            {
                "type": "Microsoft.Insights/diagnosticSettings",
                "name": "diag-law-kv",
                "scopeType": "Microsoft.KeyVault/vaults",
                "scopeName": "vd-kv-platform-aaaaaaaaaaaaaaaa",
                "properties": {
                    "workspaceId": "/subs/abc/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/law",
                    "logs": [{"category": "AuditEvent", "enabled": True}],
                    "metrics": [{"category": "AllMetrics", "enabled": True}],
                },
            },
        ],
    }

    exp_path = _write(tmp_path, "expected.json", expected)
    act_path = _write(tmp_path, "actual.json", actual)

    # Should not raise
    compare_expected_actual(exp_path, act_path)


def test_compare_raises_on_missing_resource(tmp_path: Path):
    expected = {"resources": [{"type": "Microsoft.Network/virtualNetworks", "name": "vd-vnet-platform-<16>"}]}
    actual = {"resources": []}
    exp_path = _write(tmp_path, "expected.json", expected)
    act_path = _write(tmp_path, "actual.json", actual)

    with pytest.raises(AssertionError):
        compare_expected_actual(exp_path, act_path)

