# Managed Application Registry

Approver: Umesh Kakkad
Owning Team: Platform
Created by: Hemanta Banerjee
Reviewers: Shwetank Sheel
Status: Accepted
Type: Standard
ID: RFC-45
PRDs: Marketplace Deployment (https://www.notion.so/Marketplace-Deployment-2bc309d25a8c806ea40fd88b75dab0dc?pvs=21), HMAC Rotation Engine (https://www.notion.so/HMAC-Rotation-Engine-2da309d25a8c80ebbe0ef38fb12ec3ca?pvs=21), TLS Certificate Rotation Engine (https://www.notion.so/TLS-Certificate-Rotation-Engine-2da309d25a8c80ada0e6db3358520625?pvs=21), Update Engine (https://www.notion.so/Update-Engine-2da309d25a8c80738874dc01fe245224?pvs=21), Health Service (https://www.notion.so/Health-Service-2da309d25a8c80628dbefb0d7023821e?pvs=21), AKS and Airbyte Deployment (https://www.notion.so/AKS-and-Airbyte-Deployment-2da309d25a8c80b5ae8ddaf0f4e2a6a8?pvs=21), Mandatory Runbooks (https://www.notion.so/Mandatory-Runbooks-2db309d25a8c801caaf2e92c498eb07c?pvs=21)
Authors: Hemanta Banerjee

# Decision:

Registry single source of truth for all components and configuration for the managed application. 

# **Summary**

Registry is the source of truth for the following 

- Azure resources deployed from the marketplace
- Vibedata application artifacts - container apps, app services, function apps, agents, automation runbooks etc.
- Data Domains artifacts
    - Fabric resources - Tenant, Workspace, Lakehouse
    - Github resources - Repo, branches

Registry is stored in Postgres database. 

# Context

- We need a consistent mechanism to get all the deployed components for tasks such as upgrade, health check and monitoring.
- Vibedata registry is used to capture this information.

# Proposal

Registry is the source of truth for the components deployed in the managed app and maps expected components to runtime targets. 

**Technology:** PostgreSQL Flexible Server

**Bootstrapping:**  See Section 5 (Bootstrap Flow).

**Backup:** Covered by PostgreSQL automated backups (Section 7.1)

**Access Pattern:**

- Bulk operations (bootstrap, health checks): Direct SQL queries
- Single resource updates: Single resource updates: JSONB field updates using optimistic concurrency control (CAS)
- API layer: PostgreSQL → REST API → Consumers

**Concurrency Control (Optimistic / CAS):** 

- All registry updates MUST use optimistic concurrency control to prevent lost updates when multiple workflows (e.g. streaming updates, health checks) write to the registry.
- registryVersion (etag) is a monotonically increasing integer that is incremented on every successful registry write and used for optimistic concurrency (CAS).
- Writers MUST:
    - Read the current registryVersion
    - Apply a JSONB patch/update
    - Write back using compare-and-set: update succeeds only if registryVersion matches the expected value, and MUST increment registryVersion on success
    - If the update affects 0 rows (etag mismatch), the writer MUST reload the latest registry state, re-evaluate intent (do not replay stale transitions), and then retry or no-op based on the latest state.
- Bootstrap Exception: Bootstrap is the only operation that creates the registry without CAS validation. It initializes registryVersion to 1. All subsequent updates use CAS.

**Updates:** 

- Streaming updates – On successful deployment, update registry fields using optimistic concurrency control (CAS) via registryVersion.
- Health checks – Update health and lastHealthCheckAtUtc using optimistic concurrency control (CAS) via registryVersion.

**API** 

- GET `/api/instances/{instanceId}/registry` returns the registry for the managed app.
- GET `/api/instances/{instanceId}/components/{componentId}` returns the registry for a specific resource

## **1. Registry Schema**

All fields in the registry, including instanceLock, are subject to CAS semantics via registryVersion.

```json
{
  "schemaVersion": "1.0",
  "registryVersion": 42,
  "instanceId": "...",
  "applicationId": "...",
  "managedResourceGroupId": "...",
  "fqdn": "vd-abc123xy.azurewebsites.net",
  "appgwTLSCertificate": { 
	  "secretName": "...",
	  "lastUpdatedAtUtc": "..."
  },  
  "healthPolicy": {
    "schedule": "0 * * * *",
    "maxConcurrentChecks": 20,
    "durableFunctionTimeout" : 3600,
  },
  "healthStatus": {
    "health": "Healthy | Degraded | Unknown",
    "lastHealthCheckAtUtc": "..."
  },
  "updatePolicy": {
    "autoUpdateEnabled": true,
    "updateWindowStartUtc": "",
    "updateWindowEndUtc": "",
    "releaseChannel": "stable|beta",
    "visibilityTimeoutSeconds": 86400,
    "durableFunctionTimeout" : 3600,
    "retryAttempts" : 5, 
    "maxConcurrentUpdates": 20,
    "vibedataAcrTokenSecretName": "",
    "vibeDataAcrTokenPasswordSecretName": "",
    "artifactStorageAccount": "mystorageaccount",
    "artifactContainer": "artifacts",
    "repositories": {
      "manifest" : "vibedata/manifest",
      "images": "vibedata/images",
      "appService": "vibedata/app-service",
      "functions": "vibedata/functions",
      "agents": "vibedata/agent",
      "logicApps": "vibedata/logicapps",
      "runbooks": "vibedata/runbooks",
      "schema": "vibedata/schema"
    }
  },
  "hmacKey": {
    "secretName": "hmac-signing-key-new",
    "lastUpdatedAtUtc": "2025-12-17T00:00:00Z"
  },
  "createdStatus" : 
    "createdAtUtc": "...",
    "plan": {
		    "publisher": "id",
		    "product": "offer",
		    "name": "sku",
		    "version": "1.0.1"
		 }
	},
  "updateStatus": {
    "currentVersion": "4.2.5",
    "previousVersion": "3.2.5",
    "desiredVersion": "...",
    "lastUpdateAtUtc": "...",
    "status": "Success | Failed | Pending"
}
  "instanceLock" : {
		  "lockDurationSeconds" : 3600,
	    "lockJobId" : "",
	    "lockUntilUtc" : ""
  },
  "engineTablesConfig": {
    "storageAccountName": "...",
    "dlqTableName": "engineDlq",
    "historyTableName": "engineHistory",
    "retentionDays": 90
  }
  "networkRetryPolicies": {
    "retryCount": 3,
    "retryDelaySeconds": 2
  },
  "components": [],
  "dataDomains": []
}
```

### **1.1 Components**

```json
{
  "componentId": "01HABC...",
  "name": "studio-service",
  "componentPath": "/app/studio",
  "autoUpdateEnabled": true,
  "rtype": "managedClusters",
  "artifactType": "container",
  "deploymentRunbook": "",
  "currentVersion": "1.3.1",
  "lastUpdatedAtUtc": "...",
  "previousVersion": "1.2.0",
  "healthPolicy": {
    "healthEndpointType": "API | runbook | Unknwown",
    "healthEndpoint": "/health",
    "httpTimeoutSeconds": 10,
  },
  "healthStatus": {
    "health": "Healthy | Degraded | Unknown",
    "lastHealthCheckAtUtc": "..."
  },
}
```

**Resource Types**

- For Azure resources: Maps logical component names to Azure resource types for registry tracking.
- For non azure resources: Custom

| Component | Azure Resource Type | Registry rtype Value |
| --- | --- | --- |
| **Compute & Application** |  |  |
| App Service Plan | Microsoft.Web/serverfarms | serverfarms |
| App Service | Microsoft.Web/sites | sites |
| Function App | Microsoft.Web/sites | sites.functions |
| Logic App | Microsoft.Logic/workflows | workflows |
| AKS | Microsoft.ContainerService/managedClusters | managedClusters |
| Airbyte |  | logical.aks.Airbyte |
| Airbyte Custom Connector |  | logical.aks.AirbyteConnector |
| **Networking** |  |  |
| App Gateway | Microsoft.Network/applicationGateways | applicationGateways |
| NSG | Microsoft.Network/networkSecurityGroups | networkSecurityGroups |
| NSG Security Rule |  Microsoft.Network/networkSecurityGroups/securityRules | securityRules |
| Virtual Network | Microsoft.Network/virtualNetworks | virtualNetworks |
| Subnet  | Microsoft.Network/virtualNetworks/subnets | subnets |
| Private DNS Zone | Microsoft.Network/privateDnsZones | privateDnsZones |
| Private DNS Zone VNet Link | Microsoft.Network/privateDnsZones/virtualNetworkLinks | virtualNetworkLinks |
| **Data & Storage** |  |  |
| PostgreSQL | Microsoft.DBforPostgreSQL/flexibleServers | flexibleServers |
| Database Schema |  | logical.DatabaseSchema |
| Database User |  | logical.DatabaseUser |
| Database Role |  | logical.DatabaseRole |
| Storage Queue | Microsoft.Storage/storageAccounts/queueServices | queueServices |
| Storage Table | Microsoft.Storage/storageAccounts/tableServices | tableServices |
| Azure Storage | Microsoft.Storage/storageAccounts | storageAccounts |
| ACR | Microsoft.ContainerRegistry/registries | registries |
| **AI & Search** |  |  |
| Azure Search | Microsoft.Search/searchServices | searchServices |
| Azure Foundry | Microsoft.CognitiveServices/accounts | cognitiveServices |
| AI Foundry Project |  | Logical.AIFoundry.Project |
| Hosted Agent |  | Logical.AIFoundry.Agent |
| **Operations** |  |  |
| Key Vault | Microsoft.KeyVault/vaults | vaults |
| Key Vault Secret |  | logical.KeyVaultSecret |
| Log Analytics Workspace | Microsoft.OperationalInsights/workspaces | operationalInsightsWorkspaces |
| Automation Account | Microsoft.Automation/automationAccounts | automationAccounts |
| Automation Runbook | Microsoft.Automation/automationAccounts/runbooks | automationAccountsRunbooks |
| **Identity** |  |  |
| User Assigned Managed Identity | Microsoft.ManagedIdentity/userAssignedIdentities | userAssignedIdentities |
| Service Principal |  | logical.ServicePrincipal |

### **1.2. Data Domains**

Captures the details for the data domains in the managed application. 

```json
{
  "dataDomainId": "01HABC...",
  "name": "sales-domain",
  "createdAtUtc": "...",
  "lastUpdatedAtUtc": "...",
  "status": "Active | Pairing | Failed | Disabled",
  "fabricWorkspace": {
    "workspaceId": "guid",
    "workspaceName": "...",
    "tenantId": "guid",
    "monitoring": {
      "enabled": true,
      "eventhouseId": "guid",
      "eventhouseName": "...",
      "dataActivatorAlertId": "guid",
      "webhookConfigured": true,
      "lastCheckedAtUtc": "..."
    }
  },
  "github": {
    "repoId": "...",
    "repoName": "org/repo",
    "branch": "main",
    "path": "/domains/sales"
  },
  "healthStatus": {
    "health": "Healthy | Degraded | Unknown",
    "lastHealthCheckAtUtc": "..."
  }
}
```

---

## 2. **Registry Versioning and Compatibility**

1. schemaVersion is schema version of the registry payload.
2. Backward compatibility rule: All readers of the registry MUST treat unknown fields as optional and ignore them. 
3. Version bump policy:
    - Additive changes (new optional fields) do not bump schemaVersion.
    - Breaking changes (rename/remove/semantic change of existing fields) **MUST** bump schemaVersion and require a new marketplace major offer.

## 3. Concurrency Control (Optimistic / CAS)

All registry updates across the platform MUST use optimistic concurrency control:

1. `registryVersion` is a monotonically increasing integer incremented on every successful write
2. Writers MUST:
    - Read current `registryVersion`
    - Apply update
    - Write with CAS: succeeds only if `registryVersion` matches expected value
    - Increment `registryVersion` on success
3. On CAS failure (0 rows affected):
    - Reload latest state
    - Re-evaluate intent (do not replay stale transitions)
    - Retry or no-op based on latest state
4. Bootstrap is the only exception: initializes `registryVersion` to 1 without CAS

This pattern applies to:

- Managed App Registry (this document)
- Publisher Registry (RFC-54)
- All engines writing to registries (RFC-44, RFC-52, RFC-53, RFC-55)

## 4. **Registry Lock**

1. instanceLock is used by health checks and streaming updates to prevent concurrent modification of the same registry instance.
2. instanceLock MUST be acquired using an atomic compare-and-set (CAS) update against the registry row. Lock acquisition MUST fail if a valid lock already exists.
3. Only the holder of instanceLock (matching lockJobId and unexpired lockUntilUtc) is permitted to modify the registry.
4. Lock acquisition and registry updates MUST both use optimistic concurrency control via registryVersion.

---

## 5. Bootstrap Flow

Bootstrap is the final step of marketplace deployment. It validates deployed resources against the manifest and initializes the registry.

### 5.1 Trigger

- Runs as automation runbook invoked by Bicep deployment script
- Prerequisites:
    - Manifest available in artifact storage
    - All Azure resources deployed
    - All container images and OCI artifacts imported to Customer ACR
    - All mandatory runbooks published to Automation Account
    - vibedata-uami active with required RBAC

### 5.2 Discovery

**Infrastructure Resources:**

- Uses `az resource list --resource-group {mrg}` to enumerate all Azure resources in MRG
- vibedata-uami Contributor role on MRG provides required access
- Returns list of deployed resource IDs and types

**Application Artifacts:**

- App Services: query deployed container image tags
- Function Apps: query deployed container image tags
- Database schemas: query PostgreSQL for deployed schemas and migrations
- Automation Runbooks: query Automation Account for deployed runbooks
- Logic Apps: query deployed workflow definitions
- AKS workloads: query deployed Helm releases and pods
- AI Foundry: query deployed projects and agents

### 5.3 Validation

**Infrastructure Validation:**

- Compares manifest infrastructure components against discovered Azure resources
- Match criteria: resource exists, resource type matches, resource is accessible

**Application Artifact Validation:**

- Compares manifest application components against deployed artifacts
- Match criteria: artifact deployed, version matches manifest (using `latest` tag)

**Mismatch Handling:**

| Condition | Result |
| --- | --- |
| Infrastructure resource in manifest but not deployed | Deployment fails |
| Infrastructure resource deployed but not in manifest | Deployment fails |
| Application artifact in manifest but not deployed | Deployment fails |
| Application artifact deployed but not in manifest | Deployment fails |
| Version mismatch | Deployment fails |

### 5.4 Registration

**Instance Initialization:**

- Generate unique instanceId (nanoid) for the instance
- Set fqdn to `{instanceId}.vibedata.ai`
- Store instanceId and fqdn in registry
- Set schemaVersion to current schema version
- Set registryVersion to 1
- Initialize healthPolicy with platform defaults
- Initialize updatePolicy with platform defaults
- Initialize networkRetryPolicies with platform defaults
- Initialize instanceLock as empty (no active lock)

**Infrastructure Component Registration:**

For each matched infrastructure resource:

- Generate instance-scoped componentId
- Map manifest component name to componentId
- Record resource ID, resource type
- Record private FQDN, endpoints
- Set component version from manifest

**Application Artifact Registration:**

For each matched application artifact:

- Generate instance-scoped componentId
- Map manifest component name to componentId
- Record deployment target (App Service name, Function App name, AKS namespace, etc.)
- Record artifact reference (container image, runbook name, schema version, etc.)
- Set component version from manifest

**Health Initialization:**

- Execute health check for each component per Section 3
- Set component health status based on result
- Aggregate component health to instance health per Section 3.1

### 5.5 Failure Behavior

| Condition | Result |
| --- | --- |
| Runbook not found in Automation Account | Deployment fails |
| Resource in manifest but not deployed | Deployment fails |
| Resource deployed but not in manifest | Deployment fails |
| Health check fails for any component | Deployment fails |
| Partial registration (some succeed, some fail) | Deployment fails |
- All failures surface to ARM as deployment failure
- Customer sees failure in Azure portal
- No partial success or degraded state allowed
- Recovery: delete managed app and redeploy

### 5.6 Idempotency

- Bootstrap does not support re-run
- Failed deployment requires delete and redeploy
- No registry cleanup or rollback mechanism

# Impact

- None

---

# Open Questions

- 
- 
- 
-