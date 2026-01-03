# 📜 Sequence of Marketplace Deployment

**RFC ID:** RFC-60  
**Status:** Accepted  
**Type:** Design  
**Owning Team:** Platform

**URL:** https://www.notion.so/2d8309d25a8c805ab5dbe18cccfe95f9

---

# Decision:
- Vibedata will use a deterministic, phased deployment sequence
- The sequence defines the mandatory order and is authoritative for Marketplace (Day-0) deployment only
- The sequence explicitly does not cover Day-2 operations (Streaming updates), Rollbacks or upgrades

---

# **Summary**
This RFC defines the end-to-end deployment sequence. The sequence in the proposal establishes a known-good baseline state.

---

# Context
Vibedata is deployed via Azure Marketplace as an **Azure Managed Application (AMA)**, which imposes strict constraints on deployment ordering, identity resolution, and secret access.
- Marketplace offers are immutable; therefore, all bootstrap logic must succeed deterministically during initial ARM/Bicep execution.
- All platform services are deployed with private endpoints only, requiring networking, DNS, and identity to be established before any application workloads start.
- A single User-Assigned Managed Identity (vibedata-UAMI) is used to execute all bootstrap actions, making early identity and RBAC setup mandatory.
- The platform registry and health system depend on fully resolved private endpoints and deployed components and therefore must be initialized last.

This RFC defines only the Day-0 deployment sequence and establishes a known-good baseline state.

# Proposal
The sequence of marketplace deployment is below.

| Phase | **Action** |
|-------|------------|
| **Prereqs and Identity** | 1. Create vibedata-UAMI<br>2. Assign Day-2 baseline RBAC (at the right scopes) |
| **Observability Foundation** | 1. Create a Log Analytics workspace. <br>2. From this point on, configure all services to send their diagnostic settings to this workspace. |
| **Network Foundation** | Create the VNet, SNets and NSG rules |
| **DNS Infrastructure** | Create all required Private DNS Zones and link to VNet. |
| **Core Security** | 1. Create Key Vault and configure for private access. <br>2. Enable soft delete + purge protection, lock down public network<br>3. Assign UAMI required RBAC. |
| **Foundation PaaS Services** | 1. Provision foundation PaaS services and configure for private access<br>- Storage container <br>- Storage Queue<br>- Storage Table<br>- Storage Blob <br>- Automation Account (no runbooks)<br><br>2. Assign UAMI required RBAC. |
| **Artifact Bootstrap ** | 1. Import manifest from Publisher ACR → Customer ACR using `latest` tag <br>2. Import images from Publisher ACR → Customer ACR using `latest` tag (image list hardcoded in Bicep) <br>3. Store manifest in artifact storage (Blob) for registry bootstrap and streaming updates |
| **Runbook Bootstrap** | 1. Extract runbook OCI artifacts from artifact storage<br>2. Publish all mandatory runbooks to Automation Account<br>3. Validate runbook registration |
| **DB Deployment ** | 1. Provision Postgres SQL and configure for private access <br>2. Assign UAMI required RBAC access <br>3. Deploy DB schema/migrations |
| **App Deployment ** | Deploy App services  (parallel where possible) <br>- App Service Plan + Apps<br>- Azure Functions |
| **Airbyte Deployment** | 1. Deploy AKS cluster and configure for private access<br>2. Deploy Airbyte to AKS |
| **App GW Deployment** | Deploy App gateway, WAF and backend pools. |
| **AI Deployment** | 1. Deploy AI Services and configure for private access <br>- AI Foundry <br>- AI Search <br><br>2. Assign UAMI required RBAC access<br>3. Create AI Foundry Hub, Projects, indexes and hosted agents. |
| **Registry Bootstrap ** | 1. Discover deployed resources<br>2. Bootstrap/initialize your platform registry<br>3. Write all endpoints (private FQDNs), resource IDs, and configuration references |
| Health Bootstrap | Run comprehensive health check and update health status in registry |

---

# Open Questions
	- 
	- 
	- 
	-

