# 💡 Marketplace Deployment

**PRD ID:** PRD-19  
**Status:** Draft  
**Priority:** High  
**Area:** Deployment & Upgrade  
**Impact Type:** Customer

**Owner:** [User mentioned in Notion]  
**Approver:** [User mentioned in Notion]  
**Reviewers:** [User mentioned in Notion]

**URL:** https://www.notion.so/2bc309d25a8c806ea40fd88b75dab0dc

---

## Goals
Deployment of Vibedata from Azure marketplace

## Definition of Done
Successfully deploy Vibedata applications and able to login to Control Panel and Airbyte UI using their Entra ID and perform initial Tenant configuration

## Primary Actor
Customer Azure Admin

## Non-Goals
Flows within Vibedata including upgrade

---

# 1. Objective
Enable customers to deploy Vibedata from Azure Marketplace with a single click, with fully automated provisioning, publisher registration, and post-deployment bootstrap.

---

# 2. Requirements
## 2.1 Functional Requirements
| ID | Requirement |
|----|-------------|
| FR-1 | Customer can discover and deploy Vibedata from Azure Marketplace |
| FR-2 | Marketplace deployment UI collects parameters per RFC-64 schema |
| FR-3 | Deployment executes in RFC-60 defined sequence order |
| FR-4 | Marketplace deployment provisions all Managed App resources into customer tenant (RFC-42). Application Gateway WAF configured with customer and publisher IP allowlists. Custom log table and alert rules configured per RFC-51 |
| FR-5 | Marketplace deployment provisions vibedata-uami with RBAC assignments (RFC-13). Customer admin assigned RBAC roles per RFC-13 |
| FR-6 | FR-6: Marketplace deployment imports `latest` manifest from Publisher ACR to Customer ACR (RFC-49) |
| FR-7 | Container and OCI images (including runbook artifacts) imported from Publisher ACR<br>to Customer ACR using `latest` tag (RFC-43, RFC-49) |
| FR-7a | All mandatory runbooks (RFC-43) extracted from OCI artifacts and published to Automation Account |
| FR-8 | Release manifest stored in Managed App artifact storage as immutable (RFC-49) |
| FR-9 | Managed App Registry bootstrapped with components from manifest (RFC-45) |
| FR-10 | Publisher receives Marketplace notifications for lifecycle events (RFC-55) |
| FR-11 | Publisher generates and provisions HMAC key to Managed App (RFC-53) |
| FR-12 | Publisher provisions TLS certificate, creates DNS A-record in the publisher Azure DNS Zone and updates App Gateway (RFC-62) |
| FR-13 | Publisher Registry updated with instance metadata (RFC-54) |
| FR-14 | Health Service runs and updates health for all components (RFC-52) |
| FR-15 | Deployment fails gracefully with actionable error messages |
| FR-16 | Publisher can view deployment status and health from control plane (RFC-57) |

## 2.2 Non-Functional Requirements
| ID | Requirement |
|----|-------------|
| NFR-1 | Deployment completes within 30 minutes for standard configurations |
| NFR-2 | Deployment is idempotent — retrying a failed deployment does not create duplicate resources |
| NFR-3 | Publisher→Managed App communication uses automation runbooks executing as vibedata-uami (RFC-13) |
| NFR-4 | Managed App→Publisher communication uses HMAC-authenticated APIs (RFC-53) |
| NFR-5 | No customer data transmitted to, processed, or stored in Publisher tenant (RFC-57) |
| NFR-6 | Deployment passes Azure Marketplace certification requirements |
| NFR-7 | All deployment actions logged to customer LAW for auditability |
| NFR-8 | Deployment scripts use networkRetryPolicies from registry (3 retries, 2s delay) |
| NFR-9 | Only one deployment per subscription can execute concurrently |
| NFR-10 | Bicep templates for AKS, Apps, Functions, Automation Runbooks, Logic Apps, AI Foundry Agents contain no hardcoded image tags; tags passed as parameters  (RFC-66 section 9.1) |
| NFR-11 | Same Bicep codebase used across all environments (RFC-66 Section 9.1) |

---

# 3. Acceptance Criteria
### Marketplace Offer
- [ ] Vibedata offer visible in Azure Marketplace
- [ ] Customer completes deployment using only Marketplace UI
- [ ] Deployment repeatable in same subscription without manual cleanup

### Infrastructure (Per RFC-42)
- [ ] All resources provisioned in Managed Resource Group
- [ ] Private Endpoints resolve via Private DNS Zones
- [ ] vibedata-uami has all RBAC assignments per RFC-13

### Artifact Bootstrap
- [ ] Release manifest stored in artifact storage with correct version
- [ ] All container images available in managed app ACR
- [ ] All runbook OCI artifacts available in artifact storage
- [ ] All mandatory runbooks published to Automation Account
- [ ] Runbook validation passes before registry bootstrap

### Registry Bootstrap
- [ ] Registry schema initialized
- [ ] All deployed Azure resources discovered and registered
- [ ] All application artifacts discovered and registered
- [ ] Component versions match manifest
- [ ] All endpoints and resource references recorded
- [ ] Initial health status populated

### **Release Validation**
- [ ] Bicep contains no hardcoded image version tags
- [ ] Deployment validated in isolated RG before Partner Center submission
- [ ] Manifest in Publisher ACR matches promoted stable version

### Publisher Integration (Per RFC-55)
- [ ] Publisher webhook receives and processes provisioning notification
- [ ] Instance registered in Publisher Registry with correct status
- [ ] HMAC secret bootstrapped and status recorded
- [ ] TLS certificate bootstrapped, App Gateway configured, and DNS configured
- [ ] ACR token bootstrapped and status recorded

### Accessibility
- [ ] Instance FQDN routes to Control Panel
- [ ] Customer IP ranges can access via WAF; blocked IPs cannot

### Health
- [ ] Control Panel accessible and healthy
- [ ] Studio accessible and healthy
- [ ] Airbyte accessible and healthy
- [ ] API service accessible and healthy
- [ ] Registry health status shows Healthy

### Observability
- [ ] Custom log table `VibeData_Operations_CL` available in LAW
- [ ] Alert rules deployed and configured
- [ ] Action group routing to alert processor functions

### Customer Onboarding
- [ ] Customer can complete onboarding (GitHub + Fabric)

### Deprovisioning
- [ ] Deprovisioning notification received when customer deletes Managed App

---

# 4. Dependencies
| Dependency | Type | Notes |
|------------|------|-------|
| Azure Partner Center | External | Offer publishing and certification |
| Microsoft Certification | External | Public Marketplace listing |
| Let's Encrypt | External | TLS certificate issuance (RFC-62) |
| Azure DNS Zone ([vibedata.ai](http://vibedata.ai/)) | External | Publisher-owned, must exist before DNS provisioning |
| Publisher ACR | External | Must contain manifest tagged `latest` for offer/channel |
| Publisher Key Vaults | External | Public KV (ACR secret) + Private KV (HMAC) must be provisioned |
| RFC-66 | Input | Developer and Release Pipeline Architecture - defines how artifacts reach Publisher ACR and Partner Center |
| PRD-38 | Upstream | Publisher Infrastructure - must be deployed before marketplace offer |
| PRD-43 | Input | Mandatory runbooks |
| RFC-51 | Input | Observability Standards |

---

# 5. Out of Scope
- Custom domain configuration (only `{nanoid}.vibedata.ai` supported)
- Bring-your-own TLS certificate
- Customer-managed encryption keys
- Multi-region deployment
- Advanced networking (peering, custom DNS)
- Resource tagging (resources identified via naming convention and registry)

---

# 6. Open Questions
- [ ] Private preview or public preview for initial release?
- [ ] Which Azure regions to support at launch?
- [ ] What are the minimum Azure quotas required (vCPUs, IPs, etc.)?
- [ ] Should deployment block if customer subscription has policy restrictions?
- [ ] What happens if provisioning webhook fails? (Azure retries? Manual recovery?)
- [ ] What is the rollback procedure if deployment partially succeeds?
- [ ] Should health bootstrap block deployment completion or run async?

