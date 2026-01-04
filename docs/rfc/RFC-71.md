# 📜 Infrastructure Standards

**RFC ID:** RFC-71  
**Status:** In Review  
**Type:** Standard  
**Owning Team:** Platform

**URL:** https://www.notion.so/2db309d25a8c805e9698f78d6c5438e3

---

# Decision:
All VibeData infrastructure deployments (Publisher and Managed Application) must conform to the standards defined in this RFC. These standards ensure consistency, security, and cost optimization across all environments.

---

# Summary
This RFC defines the authoritative infrastructure configuration standards for all Azure resources deployed as part of VibeData Publisher and Managed Application infrastructure. It specifies configuration patterns, security baselines, and operational settings that all IaC implementations must follow.

---

# Context
- VibeData deploys infrastructure in two contexts: Publisher tenant and Customer tenant (Managed Application).
- A single authoritative reference is needed for IaC implementation consistency.
- Standards must balance security, operational requirements, and cost optimization.
- This RFC defines **how** resources should be configured, not **which** specific resources exist (covered by RFC-42, RFC-57).

---

# Proposal
## 1. Naming Convention
All resources follow a deterministic naming convention to ensure uniqueness and traceability.

### 1.1 Naming Pattern
| Component | Pattern | Example |
|-----------|---------|---------|
| Resource Group | `vd-rg-{purpose}-{nanoid}` | `vd-rg-publisher-a1b2c3d4` |
| Standard Resource | `vd-{rtype}-{purpose}-{nanoid}` | `vd-kv-private-a1b2c3d4e5f6g7h8` |
| Storage Account | `vdst{purpose}{nanoid}` | `vdstpublishera1b2c3d4` |
| FQDN | `{nanoid}.vibedata.ai` | `x9y8z7w6.vibedata.ai` |

- `{purpose}` is optional. Used when multiple instances of the same resource type exist (e.g., `kv-private`, `kv-public`).
- `{nanoid}` is **resource-scoped** — each resource gets its own unique nanoid generated at deployment time. Resources do not share nanoids.

### 1.2 Nanoid Specification
| Setting | Value |
|---------|-------|
| Character Set | Lowercase alphanumeric (a-z, 0-9) |
| Length (Resource Group) | 8 characters |
| Length (Resources) | 16 characters |
| Length (Storage Account) | 8 characters (due to 24-char limit) |
| Scope | Per-resource (not shared) |
| Generation | Deterministic within deployment |

### 1.3 Context-Specific Overrides
Standards in this RFC apply to Managed Application deployments by default. Publisher infrastructure has specific overrides documented below and in RFC-57.

| Resource | Managed App | Publisher |
|----------|-------------|-----------|
| ACR | Public Network Access: Disabled (Section 6.1) | Public Network Access: Enabled (Section 6.2) |
| Key Vault | Private only (Section 3.1) | Private KV + Public KV for ARM template reference (Section 3.2) |

### 1.4 Resource Type Identifiers (rtype)
| Resource | rtype |
|----------|-------|
| Key Vault | `kv` |
| Storage Account | `st` |
| PostgreSQL Flexible Server | `psql` |
| Container Registry | `acr` |
| App Service Plan | `asp` |
| App Service | `app` |
| Function App | `func` |
| Logic App | `logic` |
| Application Gateway | `agw` |
| AKS | `aks` |
| Log Analytics Workspace | `law` |
| Automation Account | `aa` |
| AI Search | `search` |
| AI Foundry (Cognitive Services) | `ai` |
| Virtual Network | `vnet` |
| Subnet | `snet` |
| Network Security Group | `nsg` |
| Public IP | `pip` |
| User Assigned Managed Identity | `uami` |
| Private Endpoint | `pe` |
| Private DNS Zone | `pdns` |
| NAT Gateway | `nat` |
| Route Table | `rt` |
| Managed Disk | `disk` |
| Network Interface | `nic` |

---

## 2. Core Networking Principles
### 2.1 Ingress Pattern
All human-facing surfaces (UI, API) are accessed exclusively through Application Gateway + WAF. No direct access to App Services, Functions, or AKS clusters.

| Traffic Type | Path |
|--------------|------|
| End User → UI/API | Internet → Application Gateway (WAF) → Private Endpoint → App Service/AKS |
| Service-to-Service | VNet → Private Endpoint → Target Service |

### 2.2 Egress Pattern
All outbound traffic from compute services uses VNet integration.

| Compute Type | Outbound Path |
|--------------|---------------|
| App Service / Functions | VNet Integration → Internet (via NSG rules) |
| AKS | Azure CNI → Internet (via NSG rules) |

### 2.3 PaaS Access Pattern
All Azure PaaS services are accessed via Private Endpoints. Public endpoints are disabled.

| Requirement | Implementation |
|-------------|----------------|
| PaaS connectivity | Private Endpoint in dedicated subnet |
| DNS resolution | Private DNS Zone linked to VNet |
| Public access | Disabled |

---

## 3. Key Vault
### 3.1 Standard Settings
| Setting | Value |
|---------|-------|
| SKU | Standard |
| RBAC Authorization | Enabled |
| Soft Delete | Enabled |
| Soft Delete Retention | 90 days |
| Purge Protection | Enabled |
| Public Network Access | Disabled |
| Private Endpoint | Required |
| Network ACLs Default Action | Deny |
| Bypass | AzureServices |

### 3.2 Publisher Key Vault Settings
Publisher operates two Key Vaults with different access patterns.
**Private Key Vault** (HMAC keys, internal secrets): follows the standard settings.
**Public Key Vault** (ACR pull secret for Marketplace deployment):

| Setting | Value |
|---------|-------|
| SKU | Standard |
| RBAC Authorization | Enabled |
| Soft Delete | Enabled |
| Soft Delete Retention | 90 days |
| Purge Protection | Enabled |
| Public Network Access | Enabled |
| Private Endpoint | Not required |
| ARM Template Deployment | Enabled |
| Appliance RP Access | Key Vault Secrets User (79f13501-948f-431a-9694-0610368efd51) |

---

## 4. Storage Account
### 4.1 Standard Settings
| Setting | Value |
|---------|-------|
| SKU | Standard_LRS |
| Kind | StorageV2 |
| Minimum TLS Version | TLS1_2 |
| Secure Transfer Required | Enabled |
| Allow Blob Public Access | Disabled |
| Shared Key Access | Disabled |
| Public Network Access | Disabled |
| Private Endpoints | blob, queue, table |

### 4.2 Access Tier by Usage Pattern
| Usage Pattern | Access Tier |
|---------------|-------------|
| Artifacts (infrequent access) | Cool |
| Operational data (queues, tables) | Hot |

### 4.3 Blob Container Settings
| Setting | Value |
|---------|-------|
| Public Access Level | Private |
| Versioning | Disabled |
| Soft Delete | Disabled |

### 4.4 Queue Settings
| Setting | Value |
|---------|-------|
| Message TTL | Not set at queue level; engines set per-message TTL as needed |
| Visibility Timeout | Not set at queue level; engines set per-message as needed |

---

## 5. PostgreSQL Flexible Server
### 5.1 Standard Settings
| Setting | Value |
|---------|-------|
| Version | 16 |
| Storage Auto-grow | Enabled |
| Public Network Access | Disabled |
| Private Endpoint | Required |
| Authentication | Entra ID (AAD) only |
| Connection Pooling (PgBouncer) | Disabled |
| High Availability | Disabled |

### 5.2 Compute Tier Options
| Tier | Use Case |
|------|----------|
| GP_Standard_D2s_v3 | Default / Small workloads |
| GP_Standard_D4s_v3 | Medium workloads |

Burstable tiers are excluded.

### 5.3 Storage Settings
| Setting | Value |
|---------|-------|
| Minimum Size | 32 GB |
| Auto-grow | Enabled |

### 5.4 Backup Settings
| Setting | Value |
|---------|-------|
| Backup Retention | 7 days (configurable 7-35) |
| Backup Redundancy | LRS |
| Geo-Redundant Backup | Disabled |

### 5.5 Database Role Pattern
Created during database provisioning for every instance.

| Role | Purpose |
|------|---------|
| `vd_dbo` | Full schema access (service identity) |
| `vd_reader` | Read-only access |

---

## 6. Azure Container Registry
### 6.1 Standard Settings
| Setting | Value |
|---------|-------|
| SKU | Premium |
| Admin User | Disabled |
| Anonymous Pull | Disabled |
| Zone Redundancy | Disabled |
| Data Endpoint | Disabled |
| Public Network Access | Disabled |
| Private Endpoint | Required |

### 6.2 Publisher ACR Settings
Publisher ACR requires public access for ARM/Marketplace deployment scripts.

| Setting | Value |
|---------|-------|
| SKU | Premium |
| Admin User | Disabled |
| Anonymous Pull | Disabled |
| Zone Redundancy | Disabled |
| Data Endpoint | Disabled |
| Public Network Access | Enabled |
| Firewall | Allow Trusted Azure Services |
| Private Endpoint | Not required |

---

## 7. App Service Plan
### 7.1 Standard Settings
| Setting | Value |
|---------|-------|
| OS | Linux |
| Zone Redundancy | Disabled |

### 7.2 SKU Options
| SKU | Use Case |
|-----|----------|
| P1v3 | Default / Small workloads |
| P2v3 | Medium workloads |
| P3v3 | Large workloads |

P1v3 is the minimum required for VNet integration.

---

## 8. App Service and Azure Functions
All App Services and Azure Functions are deployed as **containerized workloads** on App Service Plan.

### 8.1 Standard Settings
| Setting | Value |
|---------|-------|
| Deployment Type | Container |
| Hosting Plan | App Service Plan (shared) |
| HTTPS Only | Enabled |
| Minimum TLS Version | 1.2 |
| FTP State | Disabled |
| Remote Debugging | Disabled |
| Always On | Enabled |
| Public Network Access | Disabled |
| Private Endpoint | Required (inbound) |
| VNet Integration | Required (outbound) |

---

## 9. Azure Kubernetes Service (AKS)
### 9.1 Standard Settings
| Setting | Value |
|---------|-------|
| Kubernetes Version | 1.29 (latest stable) |
| Network Plugin | Azure CNI |
| Network Policy | Azure |
| API Server Access | Private (private cluster) |
| OIDC Issuer | Enabled |
| Workload Identity | Enabled |
| Managed Identity | Enabled (kubelet identity) |
| Autoscaling | Disabled |
| Upgrade Channel | patch |
| Azure Policy | Disabled |
| Defender for Containers | Disabled |

### 9.2 Node Pool Settings
| Setting | Value |
|---------|-------|
| Node Count | 2 (fixed) |
| Node OS | Ubuntu Linux |
| OS Disk Type | Ephemeral |
| OS Disk Size | 128 GB |

### 9.3 Node Size Options
| Size | vCPU | Memory | Use Case |
|------|------|--------|----------|
| Standard_D4s_v3 | 4 | 16 GB | Default / Small workloads |
| Standard_D8s_v3 | 8 | 32 GB | Medium workloads |
| Standard_D16s_v3 | 16 | 64 GB | Large workloads |

### 9.4 Workload Identity Settings
Applied to every AKS cluster with workload identity enabled.

| Setting | Value |
|---------|-------|
| Federated Credential Audience | api://AzureADTokenExchange |
| Subject Format | system:serviceaccount:{namespace}:{serviceaccount} |

---

## 10. Application Gateway + WAF
Application Gateway is the single ingress point for all human-facing traffic.

### 10.1 Standard Settings
| Setting | Value |
|---------|-------|
| SKU | WAF_v2 |
| Tier | WAF_v2 |
| Capacity | 1 (fixed) |
| Autoscaling | Disabled |
| Zone Redundancy | Disabled |
| HTTP2 | Enabled |
| Cookie-based Affinity | Disabled |
| Connection Draining | Enabled (60 seconds) |

### 10.2 WAF Settings
| Setting | Value |
|---------|-------|
| WAF Mode | Prevention |
| WAF Rule Set | OWASP 3.2 |

### 10.3 WAF Custom Rule Priority Ranges
Standard priority ranges for IP allowlist rules. Same pattern for every deployment; only IP values change.

| Range | Purpose |
|-------|---------|
| 100-199 | Allow rules (customer IPs) |
| 200-299 | Allow rules (publisher IPs) |
| 1000+ | Deny rules (block all others) |

### 10.4 SSL Settings
| Setting | Value |
|---------|-------|
| SSL Policy | AppGwSslPolicy20220101S |
| Minimum TLS Version | 1.2 |
| Backend Protocol | HTTPS |

### 10.5 Backend Pool Settings
| Setting | Value |
|---------|-------|
| Target Type | Private Endpoint FQDN or Internal FQDN |
| Protocol | HTTPS |
| Port | 443 |

### 10.6 Health Probe Settings
Every backend pool requires a health probe. Probe path is backend-specific.

| Setting | Value |
|---------|-------|
| Protocol | HTTPS |
| Path | Backend-specific (e.g., `/health`, `/api/v1/health`) |
| Interval | 30 seconds |
| Timeout | 30 seconds |
| Unhealthy Threshold | 3 |

### 10.7 HTTP Settings
| Setting | Value |
|---------|-------|
| Cookie-based Affinity | Disabled |
| Request Timeout | 60 seconds |
| Override Backend Path | No |
| Override Hostname | From backend target |

---

## 11. Log Analytics Workspace
### 11.1 Standard Settings
| Setting | Value |
|---------|-------|
| SKU | PerGB2018 |
| Retention | 30 days (configurable via runbook) |
| Daily Cap | None |
| Archive | Disabled |
| Commitment Tier | None |

---

## 12. Automation Account
### 12.1 Standard Settings
| Setting | Value |
|---------|-------|
| SKU | Basic |
| Local Authentication | Disabled |
| Public Network Access | Enabled |

Public Network Access is required for ARM-based runbook invocation.

### 12.2 Runbook Deployment Model
Automation Account is deployed empty (no runbooks embedded in Bicep).
All runbooks are:
- Packaged as OCI artifacts in Publisher ACR
- Downloaded during artifact bootstrap phase (marketplace deployment)
- Updated via streaming updates (day-2 operations)
- Published to Automation Account programmatically

This ensures runbooks are updateable without requiring new marketplace offers.

---

## 13. AI Services
Azure AI Search and Azure AI Foundry are **separate services** with independent deployments.

### 13.1 Azure AI Search
| Setting | Value |
|---------|-------|
| Replicas | 1 |
| Partitions | 1 |
| Public Network Access | Disabled |
| Private Endpoint | Required |
| Semantic Search | Disabled |

**SKU Options:**
| SKU | Use Case |
|-----|----------|
| S1 | Default / Small workloads |
| S2 | Medium workloads |
| S3 | Large workloads |

Basic tier is excluded.

### 13.2 Azure AI Foundry (Cognitive Services)
| Setting | Value |
|---------|-------|
| Kind | CognitiveServices (multi-service) |
| SKU | S0 |
| Public Network Access | Disabled |
| Private Endpoint | Required |

---

## 14. Logic Apps
### 14.1 Standard Settings
| Setting | Value |
|---------|-------|
| Plan Type | Consumption |
| State | Enabled |

---

## 15. Virtual Network
### 15.1 Standard Settings
| Setting | Value |
|---------|-------|
| DNS Servers | Azure Default |

### 15.2 Address Space
| Setting | Value |
|---------|-------|
| Minimum Size | /24 |
| Maximum Size | /16 |

### 15.3 Reserved Ranges (Must Not Overlap)
| Range | Reason |
|-------|--------|
| 10.0.0.0/8 | Common enterprise range |
| 172.16.0.0/12 | Common enterprise range |
| 192.168.0.0/16 | Common enterprise range |

### 15.4 Subnet Sizing Standards
| Purpose | Minimum Size | Delegation |
|---------|--------------|------------|
| Application Gateway | /27 | None |
| AKS Nodes | /25 | None |
| App Service Integration | /28 | Microsoft.Web/serverFarms |
| Private Endpoints | /28 | None |

### 15.5 Subnet Naming Convention
| Purpose | Name |
|---------|------|
| Application Gateway | snet-appgw |
| AKS Nodes | snet-aks |
| App Service Integration | snet-appsvc |
| Private Endpoints | snet-private-endpoints |

---

## 16. Network Security Groups
### 16.1 Default Rules (All NSGs)
| Direction | Action | Source | Destination |
|-----------|--------|--------|-------------|
| Inbound | Allow | VirtualNetwork | VirtualNetwork |
| Inbound | Deny | \* | \* |
| Outbound | Allow | VirtualNetwork | VirtualNetwork |

### 16.2 NSG Patterns by Subnet Type
**Workload Subnet (AKS, App Service Integration):**
| Direction | Rules |
|-----------|-------|
| Inbound | Deny all from Internet |
| Outbound | Allow all to Internet |

**Gateway Subnet (Application Gateway):**
| Direction | Rules |
|-----------|-------|
| Inbound | Allow TCP 443 from Internet |
| Inbound | Allow from AzureLoadBalancer |
| Inbound | Allow TCP 65200-65535 from GatewayManager |
| Outbound | Allow all |

**Private Endpoint Subnet:**
| Direction | Rules |
|-----------|-------|
| Inbound | VNet-to-VNet only |
| Outbound | VNet-to-VNet only |

---

## 17. Private DNS Zones
### 17.1 Standard Settings
| Setting | Value |
|---------|-------|
| Auto-registration | Disabled |
| VNet Link | Required |

### 17.2 Zone by Service Type
| Service Type | Zone |
|--------------|------|
| Key Vault | privatelink.vaultcore.azure.net |
| PostgreSQL Flexible Server | privatelink.postgres.database.azure.com |
| Storage (Blob) | privatelink.blob.core.windows.net |
| Storage (Queue) | privatelink.queue.core.windows.net |
| Storage (Table) | privatelink.table.core.windows.net |
| Container Registry | privatelink.azurecr.io |
| App Service / Functions | privatelink.azurewebsites.net |
| AI Search | privatelink.search.windows.net |
| Cognitive Services | privatelink.cognitiveservices.azure.com |

---

## 18. Public IP
### 18.1 Standard Settings
| Setting | Value |
|---------|-------|
| SKU | Standard |
| Allocation Method | Static |
| Tier | Regional |

---

## 19. Observability
### 19.1 Diagnostic Settings
All resources must have diagnostic settings configured to emit to Log Analytics Workspace.

| Setting | Value |
|---------|-------|
| Destination | Log Analytics Workspace |
| Metrics | AllMetrics |

### 19.2 Log Categories by Resource Type
| Resource Type | Log Categories |
|---------------|----------------|
| Key Vault | AuditEvent |
| Storage Account | StorageRead, StorageWrite, StorageDelete |
| PostgreSQL | PostgreSQLLogs |
| ACR | ContainerRegistryRepositoryEvents, ContainerRegistryLoginEvents |
| App Service | AppServiceHTTPLogs, AppServiceConsoleLogs, AppServiceAppLogs |
| Function App | FunctionAppLogs |
| AKS | kube-apiserver, kube-controller-manager, kube-scheduler |
| Application Gateway | ApplicationGatewayAccessLog, ApplicationGatewayPerformanceLog, ApplicationGatewayFirewallLog |
| Automation Account | JobLogs, JobStreams |

---

## 20. Resource Tagging
Tags are used for non-production environments only.

### 20.1 Tag Standards
| Tag | Values | Purpose |
|-----|--------|---------|
| environment | dev, release, prod | Environment identification |
| owner | ci, {username} | Resource ownership |
| purpose | ephemeral, dev, release | Lifecycle management |
| created | ISO 8601 timestamp | Creation tracking |

### 20.2 Tagging by Context
| Context | Tagging |
|---------|---------|
| Developer environments | Applied |
| Ephemeral (CI) environments | Applied |
| Integration environments | Applied |
| Release environments | Applied |
| Production (Marketplace) | Not applied (customer controls) |

---

## 21. Security Baseline
### 21.1 Network Security
| Requirement | Implementation |
|------------|----------------|
| No public endpoints | Private Endpoints for all PaaS |
| Ingress control | WAF with IP allowlist |
| Egress control | NSG rules |
| DNS resolution | Private DNS Zones |

### 21.2 Identity Security
| Requirement | Implementation |
|------------|----------------|
| No shared credentials | Managed Identity only |
| No local auth | Disabled on all services |

### 21.3 Data Security
| Requirement | Implementation |
|------------|----------------|
| Encryption at rest | Azure-managed keys |
| Encryption in transit | TLS 1.2 minimum |
| Soft delete | Enabled for Key Vault |
| Purge protection | Enabled for Key Vault |

---

## 22. Cost Optimization
### 22.1 SKU Selection
| Principle | Guidance |
|-----------|----------|
| Start small | Use smallest SKU that meets requirements |
| Scale via runbook | Enable post-deployment scaling |

### 22.2 Storage
| Principle | Guidance |
|-----------|----------|
| Access tier | Use Cool for infrequent access |
| Redundancy | LRS unless HA required |

### 22.3 Compute
| Principle | Guidance |
|-----------|----------|
| Fixed capacity | Disable autoscaling |
| Shared plans | Multiple apps on single App Service Plan |

---

# Impact
- All IaC implementations (Bicep/Terraform) must conform to these standards.
- Deviations require explicit approval and documentation in the relevant architecture RFC.
- Architecture RFCs (RFC-42, RFC-57) define which specific resources exist; this RFC defines how they are configured.

---

# Open Questions
None.

