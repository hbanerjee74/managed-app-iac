import json
from pathlib import Path


def test_params_dev_has_required_keys():
    params_path = Path("tests/fixtures/params.dev.json")
    assert params_path.exists(), "tests/fixtures/params.dev.json is missing"

    data = json.loads(params_path.read_text())
    values = data.get("parameters", {})

    required = {
        "resourceGroup",
        "mrgName",
        "location",
        "contactEmail",
        "adminObjectId",
        "servicesVnetCidr",
        "customerIpRanges",
        "publisherIpRanges",
        "sku",
        "nodeSize",
        "computeTier",
        "aiServicesTier",
        "retentionDays",
        "appGwCapacity",
        "appGwSku",
        "storageGB",
        "backupRetentionDays",
    }

    missing = sorted(required - values.keys())
    assert not missing, f"Missing parameters in params.dev.json: {missing}"
