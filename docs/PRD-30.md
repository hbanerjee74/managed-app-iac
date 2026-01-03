# 💡 IaC for Managed Application Infrastructure Deployment

**PRD ID:** PRD-30  
**Status:** Approved  
**Priority:** High  
**Area:** Deployment & Upgrade  
**Impact Type:** Platform

**Owner:** [User mentioned in Notion]  
**Approver:** [User mentioned in Notion]  
**Reviewers:** [User mentioned in Notion]

**URL:** https://www.notion.so/2d9309d25a8c80748483cc327cb12a68

---

## Goals
Deploy all managed application Azure infrastructure enabling VibeData platform services.

## Definition of Done
All infrastructure deployed, RBAC assigned, services ready to receive application deployments.

## Primary Actor
Customer Azure Admin

## Non-Goals
AKS cluster, Airbyte deployment, application code deployment, artifact bootstrap.

---

# 1. Objective
Deploy the complete managed application infrastructure within the customer's Managed Resource Group, enabling all VibeData platform services to operate with private connectivity, secure identity, and centralized observability.

---

# 2. Requirements
Parameter handling responsibilities are split across PRDs:
- The Marketplace Deployment UI PRD validates parameter collection and client-side validation rules per RFC-64.
- PRD-30 validates that all RFC-64 parameters are:
	- correctly bound into the ARM/Bicep template
	- consumed with exact name and casing
	- correctly realized in deployed infrastructure resources.
PRD-30 does not validate UI behavior or client-side input validation.

## 2.1 Functional Requirements
| ID | Requirement |
|----|-------------|
| FR-1 | Deploy vibedata-uami and RBAC assignments per RFC-13 Section 1.2 |
| FR-2 | Deploy customer RBAC assignments per RFC-13 Section 1.3 |
| FR-3 | Deploy Log Analytics Workspace per RFC-42 Section 10 |
| FR-4 | Deploy Services VNet, subnets, and NSGs per RFC-42 Section 2.1-2.3 |
| FR-5 | Deploy Private DNS Zones per RFC-42 Section 2.4 |
| FR-6 | Deploy Key Vault per RFC-42 Section 5 |
| FR-7 | Deploy Storage Account (Blob, Queue, Table) per RFC-42 Section 9 |
| FR-8 | Deploy Container Registry per RFC-42 Section 4.1 |
| FR-9 | Deploy PostgreSQL Flexible Server per RFC-42 Section 6 |
| FR-10 | Deploy App Service Plan, App Services, and Azure Functions per RFC-42 Section 4.2-4.3 |
| FR-11 | Deploy Automation Account (empty, no runbooks) per RFC-42 Section 7 |
| FR-12 | Deploy Application Gateway + WAF per RFC-42 Section 3 |
| FR-13 | Deploy AI Services (AI Foundry, AI Search) per RFC-42 Section 8 |
| FR-15 | Configure diagnostic settings for all resources to emit to LAW |
| FR-16 | Follow deployment sequence per RFC-60 |
| FR-17 | Deploy custom log table `VibeData_Operations_CL` per RFC-51 Section 2.3 |
| FR-18 | Parameters follow RFC-64 (Marketplace Deployment Parameters) |

## 2.2 Non-Functional Requirements
| ID | Requirement |
|----|-------------|
| NFR-1 | All resources follow naming convention per RFC-71 Section 1 |
| NFR-2 | Deployment must be idempotent |
| NFR-3 | Deployment completes within 30 minutes |
| NFR-4 | All PaaS services accessible only via Private Endpoint (except Application Gateway frontend) |
| NFR-5 | Same Bicep codebase from `marketplace_iac` repo used across all environments (RFC-66 section 6) |
| NFR-6 | An automated post-deployment verification must validate that the **actual Azure resources and key configuration properties** deployed in the Managed Resource Group match an **expected deployment specification (JSON)** for the chosen parameter set. |

---

# 3. Acceptance Criteria
These acceptance criteria validate the Infrastructure-as-Code (IaC) deployment for Phase 1 of Marketplace Deployment only, executed outside of Azure Marketplace.
Validation is limited strictly to ARM/Bicep resource provisioning into a standard Azure Resource Group.

---

### Scope Boundaries (Explicit)
The following are **explicitly out of scope** for PRD-30:
- Registry bootstrap or initialization
- Artifact deployment, including:
	- containers
	- applications
	- function apps
	- runbooks
	- agents or runtime services
- Publisher provisioning workflows
- TLS certificate issuance, binding, or rotation
- DNS record creation or validation
- Runtime bootstrap or health validation
- Marketplace deployment, Managed Application, or MRG verification
- Marketplace end-to-end testing or publisher callbacks
Successful completion of PRD-30 does **not** imply that the deployed instance is reachable, secure, or operational.

---

### **Resource Group**
- [ ] Infrastructure deployment completes successfully into a target Azure Resource Group
- [ ] Resource Group exists in the expected subscription and region
- [ ] All resources created by the deployment reside **only** within the target Resource Group
- [ ] No resources are created outside the target Resource Group

### Identity
- [ ] vibedata-uami created in MRG
- [ ] vibedata-uami has Contributor on MRG
- [ ] vibedata-uami has Cost Management Reader on Subscription
- [ ] vibedata-uami has Log Analytics Contributor on LAW
- [ ] vibedata-uami has Key Vault Secrets Officer on Key Vault
- [ ] vibedata-uami has Storage Blob Data Contributor on Storage Account
- [ ] vibedata-uami has AcrPull and AcrPush on ACR
- [ ] vibedata-uami has PostgreSQL Flexible Server Administrator on PostgreSQL
- [ ] vibedata-uami has Automation Job Operator on Automation Account
- [ ] vibedata-uami has Cognitive Services Contributor on AI Services
- [ ] Customer adminObjectId has Reader on MRG
- [ ] Customer adminObjectId has Automation Job Operator on Automation Account

### Observability
- [ ] LAW deployed with PerGB2018 SKU, 30-day retention
- [ ] All resources emit diagnostics to LAW (metrics and logs per RFC-71 Section 19.2)
- [ ] Custom table `VibeData_Operations_CL` created in LAW

### Networking
- [ ] VNet deployed with address space from `servicesVnetCidr` parameter
- [ ] Subnets created: `snet-appgw` (/27), `snet-aks` (/25),  `snet-private-endpoints` (/28)
- [ ] NSGs attached to all subnets
- [ ] App Gateway subnet NSG: allows TCP 443 from Internet, AzureLoadBalancer, TCP 65200-65535 from GatewayManager
- [ ] AKS subnet NSG: deny inbound from Internet, allow outbound to Internet
- [ ] Private Endpoints subnet NSG: VNet-to-VNet only
- [ ] All subnets allow VNet-to-VNet traffic
- [ ] Private DNS Zones created and linked to VNet with auto-registration disabled
- [ ] `vibedata.internal` DNS zone created and linked

### Key Vault
- [ ] Key Vault deployed with RBAC authorization
- [ ] Soft delete enabled with 90-day retention
- [ ] Purge protection enabled
- [ ] Public network access disabled
- [ ] Network ACLs default action: Deny, Bypass: AzureServices
- [ ] Private Endpoint resolves via Private DNS

### Storage
- [ ] Storage Account deployed with Standard_LRS, StorageV2
- [ ] Minimum TLS version 1.2
- [ ] Secure transfer required enabled
- [ ] Shared key access disabled
- [ ] Allow blob public access disabled
- [ ] Public network access disabled
- [ ] Private Endpoints for blob, queue, table resolve via Private DNS
- [ ] Artifact blob container created with Cool access tier, Private access level
- [ ] Queues created: `health-notifications-queue`, `update-notifications-queue`, `monitor-alerts-queue`
- [ ] All queues have TTL 7 days, visibility timeout 24 hours
- [ ] Tables created: `engineHistory`, `engineDlq`

### Container Registry
- [ ] ACR deployed with Premium SKU
- [ ] Admin user disabled
- [ ] Anonymous pull disabled
- [ ] Public network access disabled
- [ ] Private Endpoint resolves via Private DNS

### Database
- [ ] PostgreSQL Flexible Server version 16 deployed
- [ ] Compute tier from `computeTier` parameter (default GP_Standard_D2s_v3)
- [ ] Storage auto-grow enabled
- [ ] Backup retention 7 days with LRS redundancy
- [ ] Entra ID authentication enabled (Entra-only, no password auth)
- [ ] Public network access disabled
- [ ] Private Endpoint resolves via Private DNS
- [ ] Database roles `vd_dbo` and `vd_reader` created
- [ ] `vd_dbo` assigned to vibedata-uami
- [ ] Database schemas deployed for vibedata services

### Compute
- [ ] App Service Plan deployed with Linux OS, SKU from `sku` parameter (default P1v3)
- [ ] Sample App Services deployed as containerized workloads
- [ ] Sample Azure Functions deployed as containerized workloads
- [ ] All services: HTTPS only enabled, minimum TLS 1.2
- [ ] All services: FTP disabled, remote debugging disabled, always on enabled
- [ ] All services have VNet integration to `snet-appsvc`
- [ ] Public network access disabled on all services
- [ ] Private Endpoints resolve via Private DNS
- [ ] All services use vibedata-uami identity

### Automation
- [ ] Automation Account deployed with `disableLocalAuth: true`
- [ ] Automation Account runs with vibedata-uami
- [ ] No runbooks embedded in Bicep deployment

### Application Gateway
- [ ] Application Gateway WAF_v2 SKU deployed in `snet-appgw`
- [ ] Capacity fixed at 1 (autoscaling disabled)
- [ ] HTTP2 enabled
- [ ] Connection draining enabled (60 seconds)
- [ ] WAF enabled in Prevention mode with OWASP 3.2 rule set
- [ ] WAF custom rules: customer IPs in priority 100-199, publisher IPs in priority 200-299, deny-all at 1000+
- [ ] Customer IP ranges allowlisted (from `customerIpRanges` parameter)
- [ ] Publisher IP ranges allowlisted (from `publisherIpRanges` parameter)
- [ ] Non-allowlisted IPs receive HTTP 403
- [ ] Public IP deployed with Standard SKU, Static allocation
- [ ] No HTTPS listener at deployment time (configured by publisher provisioning)
- [ ] No backend pools configured
- [ ] No Health probes configured
- [ ] No HTTP → HTTPS redirect rules are configured
- [ ] No TLS certificates are referenced or attached

### AI Services
- [ ] AI Search deployed with SKU from `aiServicesTier` parameter (default S1), 1 replica, 1 partition
- [ ] AI Foundry (Cognitive Services) deployed with S0 SKU
- [ ] Public network access disabled on both
- [ ] Private Endpoints resolve via Private DNS

### Logic Apps
- [ ] Logic Apps (Consumption) deployed for email notifications

### Integration
- [ ] All Private Endpoints resolve via Private DNS from within VNet
- [ ] App Services can connect to all PaaS services via Private Endpoints
- [ ] Redeployment succeeds without errors

---

# 4. Dependencies
| Dependency | Type | Notes |
|------------|------|-------|
| RFC-42 | Input | Managed Application Architecture |
| RFC-13 | Input | Identity Architecture |
| RFC-51 | Input | Observability Standards |
| RFC-60 | Input | Deployment sequence |
| RFC-64 | Input | Marketplace deployment parameters |
| RFC-66 | Input | Developer and Release Pipeline Architecture - IaC release flow |
| RFC-71 | Input | Infrastructure Standards (configuration settings) |
| RFC-72 | Input | Unified DLQ table schema |
| PRD-19 | Parent | Marketplace Deployment |

---

# 5. Out of Scope
- AKS cluster deployment
- Airbyte deployment
- Artifact bootstrap
- Registry bootstrap
- Application code deployment
- TLS certificate provisioning (RFC-62, post-deployment)
- DNS A-record creation (RFC-62, post-deployment)
- HMAC key provisioning (RFC-53, post-deployment)

---

# 6. Open Questions
None.

