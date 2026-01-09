import json
from pathlib import Path


def test_params_dev_has_required_keys():
    """Validate that params.dev.json contains all required parameters for main.bicep."""
    params_path = Path("tests/fixtures/params.dev.json")
    assert params_path.exists(), "tests/fixtures/params.dev.json is missing"

    data = json.loads(params_path.read_text())
    values = data.get("parameters", {})

    # Required parameters per main.bicep (RFC-64)
    # Note: customerAdminObjectId has a default in params.dev.json but will be overridden by deployer identity for non-managed apps
    required = {
        "contactEmail",
        "customerAdminObjectId",
        "vnetCidr",
        "customerIpRanges",
        "publisherIpRanges",
        "sku",
        "nodeSize",
        "psqlComputeTier",
        "jumpHostComputeTier",
        "aiServicesTier",
        "retentionDays",
        "appGwCapacity",
        "appGwSku",
        "storageGB",
        "backupRetentionDays",
        "customerAdminPrincipalType",
    }

    missing = sorted(required - values.keys())
    assert not missing, f"Missing parameters in params.dev.json: {missing}"


def test_params_dev_has_metadata():
    """Validate that params.dev.json has metadata section with RG name and location."""
    params_path = Path("tests/fixtures/params.dev.json")
    assert params_path.exists(), "tests/fixtures/params.dev.json is missing"

    data = json.loads(params_path.read_text())
    metadata = data.get("metadata", {})
    
    assert "resourceGroupName" in metadata, "metadata.resourceGroupName is required"
    assert "location" in metadata, "metadata.location is required"
    assert metadata.get("resourceGroupName"), "metadata.resourceGroupName cannot be empty"
    assert metadata.get("location"), "metadata.location cannot be empty"
