"""
Collect detailed actual-state JSON for comparison against the expectation template.
Requires az CLI logged in and access to the target RG.

Usage:
  python tests/validator/collect_actual_state.py <resource_group> > /tmp/actual.json

The output now includes a resource-level array with key properties captured
per resource to validate against Bicep-defined settings.
"""

import json
import subprocess
import sys


def az(cmd: list[str]) -> dict:
    result = subprocess.run(["az", *cmd, "-o", "json"], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def main():
    if len(sys.argv) < 2:
        print("Usage: python collect_actual_state.py <resource_group>", file=sys.stderr)
        sys.exit(1)
    rg = sys.argv[1]

    out: dict = {"resourceGroup": rg, "names": {}, "network": {}, "tags": {}, "resources": []}

    # RG metadata
    rg_info = az(["group", "show", "-n", rg])
    out["location"] = rg_info.get("location")
    out["tags"] = rg_info.get("tags", {})

    # Resources by type
    resources = az(["resource", "list", "-g", rg])

    resource_index = {r["id"]: {"type": r["type"], "name": r["name"]} for r in resources if r.get("id")}
    if rg_info.get("id"):
        resource_index[rg_info["id"]] = {"type": "Microsoft.Resources/resourceGroups", "name": rg}

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

    nsgs = find_by_type("Microsoft.Network/networkSecurityGroups")

    def nsg_by_suffix(suffix: str):
        for n in nsgs:
            if f"-nsg-{suffix}-" in n["name"]:
                return n["name"]
        return None

    out["names"].update(
        {
            "nsgAppgw": nsg_by_suffix("appgw"),
            "nsgAks": nsg_by_suffix("aks"),
            "nsgAppsvc": nsg_by_suffix("appsvc"),
            "nsgPe": nsg_by_suffix("pe"),
        }
    )

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
        # capture NSGs for subnets
        out["network"]["subnetNsgs"] = {s["name"]: s.get("networkSecurityGroup", {}).get("id") for s in subnets}
        out["network"]["subnetsDetailed"] = [
            {
                "name": s["name"],
                "addressPrefix": s.get("addressPrefix") or (s.get("addressPrefixes", []) or [None])[0],
                "networkSecurityGroupId": s.get("networkSecurityGroup", {}).get("id"),
                "delegations": [
                    {"serviceName": d["properties"].get("serviceName")} for d in s.get("delegations", [])
                ],
                "privateEndpointNetworkPolicies": s.get("privateEndpointNetworkPolicies"),
                "privateLinkServiceNetworkPolicies": s.get("privateLinkServiceNetworkPolicies"),
            }
            for s in subnets
        ]

    # Private DNS zones
    pdns = find_by_type("Microsoft.Network/privateDnsZones")
    out["network"]["privateDnsZones"] = [z["name"] for z in pdns]

    def add_resource(resource: dict):
        out["resources"].append(resource)

    def scope_info(scope_id: str):
        info = resource_index.get(scope_id)
        if not info:
            return None, None
        return info.get("type"), info.get("name")

    def add_role_assignments(scope_id: str):
        if not scope_id:
            return
        try:
            assignments = az(["role", "assignment", "list", "--scope", scope_id])
        except subprocess.CalledProcessError:
            return
        scope_type, scope_name = scope_info(scope_id)
        for a in assignments:
            add_resource(
                {
                    "type": "Microsoft.Authorization/roleAssignments",
                    "name": a.get("name"),
                    "scope": scope_id,
                    "scopeType": scope_type,
                    "scopeName": scope_name,
                    "properties": {
                        "roleDefinitionId": a.get("roleDefinitionId"),
                        "principalId": a.get("principalId"),
                        "principalType": a.get("principalType"),
                    },
                }
            )

    def add_diag_settings(scope_id: str):
        if not scope_id:
            return
        try:
            settings = az(["monitor", "diagnostic-settings", "list", "--resource", scope_id])
        except subprocess.CalledProcessError:
            return
        scope_type, scope_name = scope_info(scope_id)
        for s in settings:
            logs = []
            for entry in s.get("logs", []):
                log_item = {"enabled": entry.get("enabled")}
                if entry.get("category") is not None:
                    log_item["category"] = entry.get("category")
                if entry.get("categoryGroup") is not None:
                    log_item["categoryGroup"] = entry.get("categoryGroup")
                logs.append(log_item)
            metrics = []
            for entry in s.get("metrics", []):
                metric_item = {"enabled": entry.get("enabled")}
                if entry.get("category") is not None:
                    metric_item["category"] = entry.get("category")
                if entry.get("categoryGroup") is not None:
                    metric_item["categoryGroup"] = entry.get("categoryGroup")
                metrics.append(metric_item)
            add_resource(
                {
                    "type": "Microsoft.Insights/diagnosticSettings",
                    "name": s.get("name"),
                    "scope": scope_id,
                    "scopeType": scope_type,
                    "scopeName": scope_name,
                    "properties": {
                        "workspaceId": s.get("workspaceId"),
                        "logs": logs,
                        "metrics": metrics,
                    },
                }
            )

    add_role_assignments(rg_info.get("id"))

    # Helper to fetch NSG rules
    def nsg_rules(nsg_name: str):
        if not nsg_name:
            return []
        rules = az(["network", "nsg", "rule", "list", "-g", rg, "--nsg-name", nsg_name])
        return [
            {
                "name": r["name"],
                "direction": r["direction"],
                "access": r["access"],
                "protocol": r["protocol"],
                "sourceAddressPrefix": r.get("sourceAddressPrefix"),
                "sourcePortRange": r.get("sourcePortRange"),
                "destinationAddressPrefix": r.get("destinationAddressPrefix"),
                "destinationPortRange": r.get("destinationPortRange"),
                "priority": r.get("priority"),
            }
            for r in rules
        ]

    # Virtual Network
    if vnet_name:
        add_resource(
            {
                "type": "Microsoft.Network/virtualNetworks",
                "name": vnet_name,
                "location": vnet.get("location"),
                "properties": {
                    "addressSpace": vnet["addressSpace"],
                    "subnets": out["network"].get("subnets", {}),
                    "subnetNsgs": out["network"].get("subnetNsgs", {}),
                    "subnetsDetailed": out["network"].get("subnetsDetailed", []),
                },
            }
        )

    # Managed Identity
    uami_name = out["names"].get("uami")
    if uami_name:
        uami = az(["identity", "show", "-g", rg, "-n", uami_name])
        add_resource(
            {
                "type": "Microsoft.ManagedIdentity/userAssignedIdentities",
                "name": uami_name,
                "location": uami.get("location"),
                "properties": {
                    "clientId": uami.get("clientId"),
                    "principalId": uami.get("principalId"),
                },
            }
        )

    # NSGs
    for nsg_type in ["nsgAppgw", "nsgAks", "nsgAppsvc", "nsgPe"]:
        nsg_name = out["names"].get(nsg_type)
        if nsg_name:
            add_resource(
                {
                    "type": "Microsoft.Network/networkSecurityGroups",
                    "name": nsg_name,
                    "properties": {
                        "securityRules": nsg_rules(nsg_name),
                    },
            }
        )

    # Public IP for App Gateway
    pip_name = out["names"].get("pipAgw")
    if pip_name:
        pip = az(["network", "public-ip", "show", "-g", rg, "-n", pip_name])
        pip_props = pip.get("properties", pip)
        add_resource(
            {
                "type": "Microsoft.Network/publicIPAddresses",
                "name": pip_name,
                "location": pip.get("location"),
                "sku": pip.get("sku"),
                "properties": {
                    "publicIPAllocationMethod": pip_props.get("publicIPAllocationMethod"),
                    "publicIPAddressVersion": pip_props.get("publicIPAddressVersion"),
                },
            }
        )

    # Key Vault
    kv_name = out["names"].get("kv")
    if kv_name:
        kv = az(["keyvault", "show", "-n", kv_name])
        add_resource(
            {
                "type": "Microsoft.KeyVault/vaults",
                "name": kv_name,
                "location": kv.get("location"),
                "properties": {
                    "tenantId": kv["properties"].get("tenantId"),
                    "enableRbacAuthorization": kv["properties"].get("enableRbacAuthorization"),
                    "enablePurgeProtection": kv["properties"].get("enablePurgeProtection"),
                    "enableSoftDelete": kv["properties"].get("enableSoftDelete"),
                    "softDeleteRetentionInDays": kv["properties"].get("softDeleteRetentionInDays"),
                    "publicNetworkAccess": kv["properties"].get("publicNetworkAccess"),
                    "sku": kv["properties"].get("sku") or kv.get("sku"),
                    "networkAcls": kv["properties"].get("networkAcls"),
                },
            }
        )
        add_diag_settings(kv.get("id"))
        add_role_assignments(kv.get("id"))

    # Storage account
    st_name = out["names"].get("storage")
    if st_name:
        st = az(["storage", "account", "show", "-n", st_name])
        add_resource(
            {
                "type": "Microsoft.Storage/storageAccounts",
                "name": st_name,
                "location": st.get("location"),
                "sku": st.get("sku"),
                "kind": st.get("kind"),
                "properties": {
                    "allowBlobPublicAccess": st["properties"].get("allowBlobPublicAccess"),
                    "allowSharedKeyAccess": st["properties"].get("allowSharedKeyAccess"),
                    "minimumTlsVersion": st["properties"].get("minimumTlsVersion"),
                    "supportsHttpsTrafficOnly": st["properties"].get("supportsHttpsTrafficOnly"),
                    "publicNetworkAccess": st["properties"].get("publicNetworkAccess"),
                    "defaultToOAuthAuthentication": st["properties"].get("defaultToOAuthAuthentication"),
                },
            }
        )
        add_diag_settings(st.get("id"))
        add_role_assignments(st.get("id"))

    # ACR
    acr_name = out["names"].get("acr")
    if acr_name:
        acr = az(["acr", "show", "-n", acr_name])
        acr_props = acr.get("properties", {})
        add_resource(
            {
                "type": "Microsoft.ContainerRegistry/registries",
                "name": acr_name,
                "location": acr.get("location"),
                "sku": acr.get("sku"),
                "properties": {
                    "adminUserEnabled": acr.get("adminUserEnabled"),
                    "publicNetworkAccess": acr.get("publicNetworkAccess") or acr_props.get("publicNetworkAccess"),
                    "dataEndpointEnabled": acr.get("dataEndpointEnabled") or acr_props.get("dataEndpointEnabled"),
                    "zoneRedundancy": acr.get("zoneRedundancy") or acr_props.get("zoneRedundancy"),
                },
            }
        )
        add_diag_settings(acr.get("id"))
        add_role_assignments(acr.get("id"))

    # Log Analytics
    law_name = out["names"].get("law")
    if law_name:
        law = az(["monitor", "log-analytics", "workspace", "show", "--workspace-name", law_name, "-g", rg])
        add_resource(
            {
                "type": "Microsoft.OperationalInsights/workspaces",
                "name": law_name,
                "location": law.get("location"),
                "sku": law.get("sku"),
                "properties": {
                    "retentionInDays": law["retentionInDays"],
                    "features": law.get("features"),
                },
            }
        )

    # App Gateway
    agw_name = out["names"].get("agw")
    if agw_name:
        agw = az(["network", "application-gateway", "show", "-g", rg, "-n", agw_name])
        agw_props = agw.get("properties", agw)
        add_resource(
            {
                "type": "Microsoft.Network/applicationGateways",
                "name": agw_name,
                "location": agw.get("location"),
                "sku": agw.get("sku"),
                "properties": {
                    "enableHttp2": agw.get("enableHttp2") or agw_props.get("enableHttp2"),
                    "gatewayIPConfigurations": agw_props.get("gatewayIPConfigurations"),
                    "frontendIPConfigurations": agw_props.get("frontendIPConfigurations"),
                    "frontendPorts": agw_props.get("frontendPorts"),
                    "backendAddressPools": agw_props.get("backendAddressPools"),
                    "backendHttpSettingsCollection": agw_props.get("backendHttpSettingsCollection"),
                    "httpListeners": agw_props.get("httpListeners"),
                    "requestRoutingRules": agw_props.get("requestRoutingRules"),
                    "probes": agw_props.get("probes"),
                    "webApplicationFirewallConfiguration": agw_props.get("webApplicationFirewallConfiguration"),
                },
            }
        )
        add_diag_settings(agw.get("id"))

    # PostgreSQL Flexible Server
    psql_name = out["names"].get("psql")
    if psql_name:
        psql = az(["postgres", "flexible-server", "show", "-g", rg, "-n", psql_name])
        add_resource(
            {
                "type": "Microsoft.DBforPostgreSQL/flexibleServers",
                "name": psql_name,
                "location": psql.get("location"),
                "sku": psql.get("sku"),
                "properties": {
                    "version": psql.get("version"),
                    "storage": psql.get("storage"),
                    "backup": psql.get("backup"),
                    "network": psql.get("network"),
                    "authConfig": psql.get("authConfig"),
                    "highAvailability": psql.get("highAvailability"),
                },
            }
        )
        add_diag_settings(psql.get("id"))
        add_role_assignments(psql.get("id"))

    # App Service Plan
    asp_name = out["names"].get("asp")
    if asp_name:
        asp = az(["appservice", "plan", "show", "-g", rg, "-n", asp_name])
        add_resource(
            {
                "type": "Microsoft.Web/serverfarms",
                "name": asp_name,
                "location": asp.get("location"),
                "kind": asp.get("kind"),
                "sku": asp.get("sku"),
                "properties": {
                    "reserved": asp.get("reserved"),
                    "zoneRedundant": asp.get("zoneRedundant"),
                },
            }
        )

    # Web Apps + Function
    for key in ["appApi", "appUi", "funcOps"]:
        site_name = out["names"].get(key)
        if site_name:
            site = az(["webapp", "show", "-g", rg, "-n", site_name])
            identity = site.get("identity", {})
            add_resource(
                {
                    "type": "Microsoft.Web/sites",
                    "name": site_name,
                    "location": site.get("location"),
                    "kind": site.get("kind"),
                    "identityType": identity.get("type"),
                    "identityIds": list((identity.get("userAssignedIdentities") or {}).keys()),
                    "properties": {
                        "httpsOnly": site.get("httpsOnly"),
                        "publicNetworkAccess": site["properties"].get("publicNetworkAccess"),
                        "virtualNetworkSubnetId": site["properties"].get("virtualNetworkSubnetId"),
                        "siteConfig": site["properties"].get("siteConfig"),
                    },
                }
            )
            add_diag_settings(site.get("id"))

    # AI Search / Cognitive Services
    for res_key, rtype, cli_group in [
        ("search", "Microsoft.Search/searchServices", ["search", "service", "show"]),
        ("ai", "Microsoft.CognitiveServices/accounts", ["cognitiveservices", "account", "show"]),
    ]:
        name = out["names"].get(res_key)
        if name:
            res = az([*cli_group, "-g", rg, "-n", name])
            res_props = res.get("properties", {})
            properties = {
                "publicNetworkAccess": res_props.get("publicNetworkAccess"),
                "replicaCount": res_props.get("replicaCount"),
                "partitionCount": res_props.get("partitionCount"),
            }
            if res_key == "search":
                properties["hostingMode"] = res_props.get("hostingMode")
            add_resource(
                {
                    "type": rtype,
                    "name": name,
                    "location": res.get("location"),
                    "kind": res.get("kind"),
                    "sku": res.get("sku"),
                    "properties": properties,
                }
            )
            add_diag_settings(res.get("id"))

    # Automation Account
    automation_name = out["names"].get("automation")
    if automation_name:
        auto = az(["automation", "account", "show", "-g", rg, "-n", automation_name])
        auto_identity = auto.get("identity", {})
        add_resource(
            {
                "type": "Microsoft.Automation/automationAccounts",
                "name": automation_name,
                "location": auto.get("location"),
                "identityType": auto_identity.get("type"),
                "identityIds": list((auto_identity.get("userAssignedIdentities") or {}).keys()),
                "properties": {
                    "publicNetworkAccess": auto["properties"].get("publicNetworkAccess"),
                    "disableLocalAuth": auto["properties"].get("disableLocalAuth"),
                },
            }
        )
        add_diag_settings(auto.get("id"))
        add_role_assignments(auto.get("id"))

    # Private DNS zones (resources)
    for zone in pdns:
        zone_name = zone["name"]
        zone_detail = az(["network", "private-dns", "zone", "show", "-g", rg, "-n", zone_name])
        add_resource(
            {
                "type": "Microsoft.Network/privateDnsZones",
                "name": zone_name,
                "location": zone_detail.get("location"),
                "tags": zone_detail.get("tags"),
            }
        )

    # Private DNS zone links
    vnet_links = az(
        ["resource", "list", "-g", rg, "--resource-type", "Microsoft.Network/privateDnsZones/virtualNetworkLinks"]
    )
    for link in vnet_links:
        link_detail = az(["resource", "show", "--ids", link["id"]])
        parts = link["id"].split("/")
        zone_name = None
        link_name = link.get("name")
        if "privateDnsZones" in parts:
            zone_name = parts[parts.index("privateDnsZones") + 1]
        if "virtualNetworkLinks" in parts:
            link_name = parts[parts.index("virtualNetworkLinks") + 1]
        props = link_detail.get("properties", {})
        add_resource(
            {
                "type": "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
                "name": link_name,
                "zone": zone_name,
                "properties": {
                    "registrationEnabled": props.get("registrationEnabled"),
                    "virtualNetworkId": props.get("virtualNetwork", {}).get("id"),
                },
            }
        )

    # Private DNS zone groups (per private endpoint)
    zone_groups = az(
        [
            "resource",
            "list",
            "-g",
            rg,
            "--resource-type",
            "Microsoft.Network/privateEndpoints/privateDnsZoneGroups",
        ]
    )
    for group in zone_groups:
        group_detail = az(["resource", "show", "--ids", group["id"]])
        parts = group["id"].split("/")
        endpoint_name = None
        group_name = group.get("name")
        if "privateEndpoints" in parts:
            endpoint_name = parts[parts.index("privateEndpoints") + 1]
        if "privateDnsZoneGroups" in parts:
            group_name = parts[parts.index("privateDnsZoneGroups") + 1]
        props = group_detail.get("properties", {})
        configs = []
        for cfg in props.get("privateDnsZoneConfigs", []):
            cfg_props = cfg.get("properties", {})
            configs.append(
                {
                    "name": cfg.get("name"),
                    "privateDnsZoneId": cfg_props.get("privateDnsZoneId") or cfg.get("privateDnsZoneId"),
                }
            )
        add_resource(
            {
                "type": "Microsoft.Network/privateEndpoints/privateDnsZoneGroups",
                "name": group_name,
                "endpointName": endpoint_name,
                "properties": {"privateDnsZoneConfigs": configs},
            }
        )

    # Storage containers/queues/tables
    def storage_subresources(resource_type: str, name_key: str, properties_keys=None):
        items = az(["resource", "list", "-g", rg, "--resource-type", resource_type])
        for item in items:
            detail = az(["resource", "show", "--ids", item["id"]])
            name = item.get("name")
            parts = name.split("/") if name else []
            account_name = parts[0] if parts else None
            sub_name = parts[-1] if parts else None
            entry = {
                "type": resource_type,
                "name": name,
                "accountName": account_name,
                name_key: sub_name,
            }
            props = detail.get("properties", {})
            if properties_keys:
                entry["properties"] = {k: props.get(k) for k in properties_keys if k in props}
            add_resource(entry)

    storage_subresources(
        "Microsoft.Storage/storageAccounts/blobServices/containers",
        "containerName",
        ["publicAccess", "defaultEncryptionScope", "denyEncryptionScopeOverride"],
    )
    storage_subresources("Microsoft.Storage/storageAccounts/queueServices/queues", "queueName", ["metadata"])
    storage_subresources("Microsoft.Storage/storageAccounts/tableServices/tables", "tableName", None)

    # Log Analytics custom tables
    tables = az(
        [
            "resource",
            "list",
            "-g",
            rg,
            "--resource-type",
            "Microsoft.OperationalInsights/workspaces/tables",
        ]
    )
    for table in tables:
        detail = az(["resource", "show", "--ids", table["id"]])
        parts = table["id"].split("/")
        workspace_name = None
        table_name = None
        if "workspaces" in parts:
            workspace_name = parts[parts.index("workspaces") + 1]
        if "tables" in parts:
            table_name = parts[parts.index("tables") + 1]
        props = detail.get("properties", {})
        add_resource(
            {
                "type": "Microsoft.OperationalInsights/workspaces/tables",
                "name": table.get("name"),
                "workspaceName": workspace_name,
                "tableName": table_name,
                "properties": {
                    "retentionInDays": props.get("retentionInDays"),
                    "totalRetentionInDays": props.get("totalRetentionInDays"),
                    "schema": props.get("schema"),
                },
            }
        )

    # Private Endpoints (all)
    pe_list = find_by_type("Microsoft.Network/privateEndpoints")
    for pe in pe_list:
        pe_name = pe["name"]
        pe_detail = az(["network", "private-endpoint", "show", "-g", rg, "-n", pe_name])
        pe_props = pe_detail.get("properties", pe_detail)
        connections = [
            {
                "name": conn.get("name"),
                "groupIds": conn.get("groupIds") or conn.get("properties", {}).get("groupIds"),
                "privateLinkServiceId": conn.get("privateLinkServiceId")
                or conn.get("properties", {}).get("privateLinkServiceId"),
            }
            for conn in pe_props.get("privateLinkServiceConnections", [])
        ]
        add_resource(
            {
                "type": "Microsoft.Network/privateEndpoints",
                "name": pe_name,
                "location": pe_detail.get("location"),
                "properties": {
                    "subnet": pe_props.get("subnet", {}).get("id"),
                    "privateLinkServiceConnections": connections,
                },
            }
        )

    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
