"""
Collect a minimal actual-state JSON for comparison against the expectation template.
Requires az CLI logged in and access to the target RG.

Usage:
  python tests/validator/collect_actual_state.py <resource_group> > /tmp/actual.json
"""

import json
import subprocess
import sys
from pathlib import Path


def az(cmd: list[str]) -> dict:
    result = subprocess.run(["az", *cmd, "-o", "json"], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def main():
    if len(sys.argv) < 2:
        print("Usage: python collect_actual_state.py <resource_group>", file=sys.stderr)
        sys.exit(1)
    rg = sys.argv[1]

    out: dict = {"resourceGroup": rg, "names": {}, "network": {}, "tags": {}}

    # RG metadata
    rg_info = az(["group", "show", "-n", rg])
    out["location"] = rg_info.get("location")
    out["tags"] = rg_info.get("tags", {})

    # Resources by type
    resources = az(["resource", "list", "-g", rg])
    def find_by_type(rtype: str):
        return [r for r in resources if r.get("type") == rtype]

    # Name capture helpers (first match by type)
    def first_name(rtype: str):
        items = find_by_type(rtype)
        return items[0]["name"] if items else None

    # Capture expected name slots (best-effort)
    out["names"] = {
        "vnet": first_name("Microsoft.Network/virtualNetworks"),
        "kv": first_name("Microsoft.KeyVault/vaults"),
        "storage": first_name("Microsoft.Storage/storageAccounts"),
        "acr": first_name("Microsoft.ContainerRegistry/registries"),
        "psql": first_name("Microsoft.DBforPostgreSQL/flexibleServers"),
        "law": first_name("Microsoft.OperationalInsights/workspaces"),
        "agw": first_name("Microsoft.Network/applicationGateways"),
        "pipAgw": first_name("Microsoft.Network/publicIPAddresses"),
        "uami": first_name("Microsoft.ManagedIdentity/userAssignedIdentities"),
        "asp": first_name("Microsoft.Web/serverfarms"),
        "appApi": None,
        "appUi": None,
        "funcOps": None,
        "automation": first_name("Microsoft.Automation/automationAccounts"),
        "search": first_name("Microsoft.Search/searchServices"),
        "ai": first_name("Microsoft.CognitiveServices/accounts"),
    }

    # App services/function names
    sites = find_by_type("Microsoft.Web/sites")
    for s in sites:
        name = s["name"]
        if not out["names"]["appApi"]:
            out["names"]["appApi"] = name
        elif not out["names"]["appUi"]:
            out["names"]["appUi"] = name
        else:
            out["names"]["funcOps"] = name

    # Network: vnet cidr and subnets
    vnet_name = out["names"]["vnet"]
    if vnet_name:
        vnet = az(["network", "vnet", "show", "-g", rg, "-n", vnet_name])
        out["network"]["vnetCidr"] = vnet["addressSpace"]["addressPrefixes"][0]
        subnets = az(["network", "vnet", "subnet", "list", "-g", rg, "--vnet-name", vnet_name])
        out["network"]["subnets"] = {s["name"]: s["addressPrefix"] for s in subnets}

    # Private DNS zones
    pdns = find_by_type("Microsoft.Network/privateDnsZones")
    out["network"]["privateDnsZones"] = [z["name"] for z in pdns]

    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
