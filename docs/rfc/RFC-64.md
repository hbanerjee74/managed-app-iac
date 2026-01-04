# 📜 Marketplace Deployment Parameters

**RFC ID:** RFC-64  
**Status:** Accepted  
**Type:** Interface  
**Owning Team:** Publisher

**URL:** https://www.notion.so/2d9309d25a8c80a4a2d4f34bb3c7b207

---

# Decision:
Ask only those questions which impact scaling and pricing.

---

# **Summary**
During the marketplace deployment
1. We only ask what is absolutely required. Rest is defaulted.
2. We choose a logical set of defaults.
3. Anything that impacts cost can be changed after deployment using automation runbooks provided as part of the deployment.

---

# Proposal
## 1. Parameter Groups (UI Sections)
| Section | Parameters |
|---------|------------|
| **Basics** | location, contactEmail, resourceGroup (new only) |
| **Managed Application** | mrgName, adminObjectId |
| **Networking** | servicesVnetCidr, customerIpRanges, publisherIpRanges (display) |
| **Compute** | sku (App Service), nodeSize (AKS), aiServicesTier, appGwSku (display), appGwCapacity (display) |
| **Data** | computeTier (PostgreSQL), storageGB (display), backupRetentionDays (display) |
| **Monitoring** | retentionDays (display) |

## 2. Marketplace Deployment Parameters
| Service | Parameter | Validation | Default | Editable | Notes |
|---------|-----------|------------|---------|----------|-------|
| **Basics** | location | Azure regions | — | Yes | Required. Customer selects region. |
| **Basics** | contactEmail | Email format | — | Yes | Required. Used for support notifications. |
| **Resource Group** | resourceGroup | New only | — | Yes | Required. Customer must create new RG. Cannot use existing. |
| **Managed Resource Group** | mrgName | String | vd-RG-\<8-char-nanoid\> | Yes | Cannot be changed post deployment. |
| **Admin Access** | adminObjectId | GUID | — | Yes | Required. User or group ObjectID from customer Entra. |
| **VNet** | servicesVnetCidr | CIDR format, /24 to /16 | 10.100.0.0/24 | Yes | Must not overlap with 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16. Subnets derived internally. |
| **Customer IP** | customerIpRanges | Array of CIDR | — | Yes | Required. Empty = error. WAF allowlist for customer UI access. |
| **Publisher IP** | publisherIpRanges | Array of CIDR | \[Accelerate IPs\] | Display only | WAF allowlist for publisher managed services team UI access. Cannot be edited by user. |
| **Application Gateway** | appGwSku | WAF_v2 | WAF_v2 | Display only | Fixed. WAF required per RFC-42. |
| **Application Gateway** | appGwCapacity | 1-10 | 1 | Display only | Can be changed post-deployment via runbook. |
| **App Service Plan** | sku | P1v3, P2v3, P3v3 | P1v3 | Yes | Can be changed post-deploy using runbooks. |
| **AKS** | nodeSize | Standard_D4s_v3, Standard_D8s_v3, Standard_D16s_v3 | Standard_D4s_v3 | Yes | Maps to capacity tiers (S/M/L). Can be changed post-deploy. |
| **AI Services** | aiServicesTier | S1, S2, S3 | S1 | Yes | Maps to AI Search SKU only. AI Foundry uses fixed S0 SKU. Can be changed post-deploy. |
| **PostgreSQL** | computeTier | GP_Standard_D2s_v3, GP_Standard_D4s_v3 | GP_Standard_D2s_v3 | Yes | Burstable excluded. Can be changed post-deploy. |
| **PostgreSQL** | storageGB | 32-16384 | 128 | Display only | Auto-grow enabled. Can be changed post-deploy. |
| **PostgreSQL** | backupRetentionDays | 7-35 | 7 | Display only | Can be changed post-deploy using runbooks. |
| **LAW** | retentionDays | 30-730 | 30 | Display only | Can be changed post-deploy using runbooks. |

---

# Impact
- All settings that impact pricing can be changed by the customer using automation runbooks post deployment.

---

# Open Questions
	- 
	- 
	- 
	-

