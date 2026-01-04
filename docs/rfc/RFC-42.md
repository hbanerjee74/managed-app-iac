# 📜 Managed Application Architecture

**RFC ID:** RFC-42  
**Status:** Accepted  
**Type:** Architecture  
**Owning Team:** Platform

**URL:** https://www.notion.so/2d3309d25a8c8055a8e7fdda1fddcf83

---

# Decision:
VibeData is deployed via the Azure Marketplace as an **Azure Managed Application (AMA)** in the customer tenant.
Key decisions:
1. Infra is deployed using Bicep from marketplace.
2. All resources are in managed resource group (except AKS node resource group).
3. All Azure PaaS dependencies are accessed through Private Endpoints, extending the private network boundary to those services
4. All services configured to send their logs via diagnostic setting to the LAW deployed by the managed application.

# **Summary**
VibeData is deployed via the Azure Marketplace as an **Azure Managed Application (AMA)** in the customer tenant. Post deployment the customer configures their github access (using fine grained PAT) and Fabric credentials for Vibedata to be fully functional.

# Context
- Vibedata is deployed as a managed application from Azure marketplace. The proposal below covers the Azure services deployed during the marketplace deployment.
- This document does not cover updating the application artifacts - container images, logic apps, runbooks etc.

# Proposal
Each Vibedata managed application contains the following logical layers:
- **Registry** — Single source of truth for deployed components, configuration, versions, health, locks, and operational state within the managed application.
- **Update Service **- Processes publisher-initiated update requests and performs controlled upgrades of managed application components based on the release manifest.
- **Health Service **- Periodically evaluates the health of managed application components and dependent Azure services, and records normalized health state in the instance registry.
- **Control Panel** — Administrative UI for managing users, groups, RBAC, data domains, and platform metadata.
- **Studio** — Development environment for data engineers and analytics engineers to define governed silver and gold data models.
- **Assurance Agents** — Autonomous agents that monitor Azure infrastructure and platform services, react to alerts, and support Day-2 operational workflows.
- **API** — Instance API surface used to manage the instance.

The managed application provides managed ingestion using the fabric mirroring protocol using Airbyte Community Edition and custom OneLake connectors.
- **Airbyte** — Managed ingestion service used by data domain owners to ingest data into the customer's Fabric environment.

The managed application depends on the following external customer-owned data plane services:
- **Microsoft Fabric** — Hosts customer data domains, including raw/bronze, silver, and gold layers, and associated pipelines/workloads.
- **GitHub** — Source of truth for data domain specifications, dbt models, tests, and pipeline code.

---

## **1. Managed Resource Group**
All resources deployed into a single Managed Resource Group (MRG). Naming per RFC-71 Section 1.

---

## **2. Networking (Services VNet)**
### **2.1 VNet **
- A single Services VNet hosts all VibeData workloads.

---

### **2.2 Subnet**
Subnets per RFC-71 Section 15.4-15.5:
- `snet-appgw` — Application Gateway
- `snet-aks` — AKS nodes
- `snet-appsvc` — App Service VNet integration (delegated)
- `snet-private-endpoints` — Private Endpoint NICs only

---

### **2.3 NSG**
NSG rules per RFC-71 Section 16. Each subnet has an attached NSG:
- **Workload subnets** (AKS, App Service): Deny inbound from Internet, allow outbound
- **Gateway subnet**: Allow TCP 443 from Internet, GatewayManager, AzureLoadBalancer
- **Private Endpoints subnet**: VNet-to-VNet only; access governed by PaaS firewall and RBAC

---

### **2.4 Azure Private DNS Zone**
Private DNS Zones per RFC-71 Section 17.
Additional zone for internal service discovery:
- `vibedata.internal` — Airbyte internal FQDN (`vd-airbyte-{nanoid}.vibedata.internal`)

---

## **3. Application Gateway + WAF**
Configuration per RFC-71 Section 10. Deployed in `snet-appgw`.
**Traffic flow:** Internet → App Gateway/WAF → Private Endpoint → App Service/AKS
**TLS:**
- Frontend: Let's Encrypt wildcard certificate (RFC-62)
- Backend: Azure-managed certificates via Private Endpoint

---

## 4. Compute Surfaces
All Azure PaaS services use Private Endpoints with corresponding Private DNS Zones for internal name resolution.

### **4.1 ACR**
Configuration per RFC-71 Section 6.1.
- Stores container images and OCI artifacts for the managed app.
- Images originate from publisher ACR, copied to local ACR during deployment (RFC-43) and streaming updates (RFC-44).

---

### 4.2 App Service
Configuration per RFC-71 Sections 7-8.
- Single App Service Plan (Linux) hosts all App Services and Azure Functions as containerized workloads.
- Inbound: Private Endpoint only (via Application Gateway)
- Outbound: VNet Integration to `snet-appsvc`

---

### 4.3 Azure Functions
Configuration per RFC-71 Section 8. Deployed as containerized workloads on the shared App Service Plan.
Functions defined by:
- RFC-52: Health Service
- RFC-44: Update Service
- RFC-51: Alert processing

---

### **4.4 **Logic Apps
- Used for helper functions like email notifications etc.
- Logic Apps are Logic Apps consumption; deployment uses ARM/bicep templates.

---

### 4.5 AKS
Configuration per RFC-71 Section 9. Deployed in `snet-aks`.
- Hosts Airbyte only (private cluster mode).
- Airbyte core images from Docker Hub; custom connectors from local ACR.
- Deployment and updates via automation runbooks (PRD-40).

---

## **5. Key Vault**
Configuration per RFC-71 Section 3.1.
- Single Key Vault for platform and customer secrets.
- Secret segregation by prefix (convention only):
	- `customer-*` — Customer-owned (Fabric tokens, GitHub PATs)
	- `platform-*` — Publisher-owned (HMAC keys, ACR tokens)

---

## **6. Database**
Configuration per RFC-71 Section 5.
- PostgreSQL Flexible Server with Entra ID authentication.
- Schemas: vibedata services (separate per service), Airbyte metadata.
- Roles: `vd_dbo` (service identity), `vd_reader` (read-only).

---

## **7.  **Automation runbook
- All runbooks 
	- Configured with `{"properties": {"disableLocalAuth": true}}. `
	- Automation account configured to run with `vibedata-uami` identity which has contributor on MRG and required RBAC on the resources.
- 2 categories of runbooks
	- Mandatory runbooks
		- All runbooks needed during deployment and day-2 operations are packaged as OCI artifacts in publisher ACR
		- Downloaded during artifact bootstrap phase and updated via streaming updates
		- Includes: registry-bootstrap, update-component, scale-appservice, scale-aks, scale-postgresql, update-waf-allowlist, health-check-component
	- Optional runbooks
		- Additional operational runbooks distributed via runbook gallery
		- Manually added and manually updated from the gallery
- Publisher functions, App Service, Azure Functions trigger automation runbooks via ARM. 
	- Authentication is **Entra ID (OAuth2)** using either managed_application_operator (publisher) or vibedata-uami (inside customer tenant).
	- All actions logged to LAW (via diagnostic settings).

---

## 8. AI Services
### 8.1 AI Foundry
- AI Foundry hosts model access and agent projects.
- Custom AI agents deployed as containerized services (hosted agents) in Azure AI Foundry.

---

### **8.2 Azure AI Search**
- AI Search provides vector indexes.

---

## 9. Storage Services
Azure Storage subservices (Blob, Queue, Table) are not deployed into the VNet.
Access is provided via Private Endpoint NICs created in the Private Endpoints subnet, with name resolution handled through Private DNS Zones.

### 9.1 Azure Blob
Configuration per RFC-71 Section 4.
- Artifact storage with Cool access tier for infrequent access.
- Container: `artifacts` (Private access level)

---

### 9.2 Azure Queue Storage
Configuration per RFC-71 Section 4. Engines set message-level TTL and visibility timeout per their requirements.
Queues defined by:
- RFC-52: Health notifications
- RFC-44: Update notifications
- RFC-51: Alert notifications

---

### 9.3 Azure Table Storage
Configuration per RFC-72
Tables defined by:
- RFC-72: `engineDlq`, `engineHistory`

---

## 10. Log Analytics Workspace
Configuration per RFC-71 Section 11.
- Single LAW in MRG; all services emit diagnostics per RFC-71 Section 19.
- Publisher writes operational correlation logs via HTTP Data Collector API.

---

# Impact
**Alignment with WAF**

