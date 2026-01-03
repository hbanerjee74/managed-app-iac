import json
from pathlib import Path


def test_params_dev_has_required_keys():
    params_path = Path("iac/params.dev.json")
    assert params_path.exists(), "iac/params.dev.json is missing"

    data = json.loads(params_path.read_text())
    values = data.get("parameters", {})

    required = {
        "resourceGroupName",
        "location",
        "adminObjectId",
        "servicesVnetCidr",
        "customerIpRanges",
        "publisherIpRanges",
        "appServicePlanSku",
        "postgresComputeTier",
        "aiServicesTier",
        "lawRetentionDays",
    }

    missing = sorted(required - values.keys())
    assert not missing, f"Missing parameters in params.dev.json: {missing}"
