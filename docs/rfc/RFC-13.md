# 📜 Identity Architecture

**RFC ID:** RFC-13  
**Status:** Accepted  
**Type:** Design  
**Owning Team:** Platform

**URL:** https://www.notion.so/2bc309d25a8c808cb0b8f5d26f590c42

---

# Decision:
1. Publisher 
	1. Single operator group in publisher for humans 
	2. Single SPN for automations
2. Managed App Identity 
	1. Single UAMI with contributor on MRG and write access to the azure data plane. 
	2. Used for all automation in the managed app.
3. Customer 
	1. Read access on MRG with limited RBAC for Key Vault

# Context
- Vibedata is deployed as a managed app within the customer's azure tenant.
- We need to have a clear identity architecture outlining who has access to what.

# Proposal
## 1. Identity Roles Matrix
| Identity | Type | Purpose | Tenant | RBAC Scope |
|----------|------|---------|--------|------------|
| `managed_application_operators` | Entra Security Group | Publisher human administrators | Publisher | MRG in customer tenant |
| `managed_application_operator` | Service Principal (SPN) | Publisher automated operations | Publisher | Automation accounts (publisher + customer) |
| `vibedata-uami` | User-Assigned Managed Identity | Managed app automation | Customer | MRG in customer tenant |
| Customer Identity | User or Group | Customer administrators | Customer | MRG (read) + limited write |

- Authentication flow 
	- Automations (Publisher Function) : Authenticate as SPN → Connect to Customer Tenant → Trigger Automation Runbook Job → Runbook executes with vibedata-uami
	- Manual flows (Humans publisher / customer): Connect to Customer Tenant → Trigger Automation Runbook Job → Runbook executes with vibedata-uami

---

### 1.1 Publisher Identities
- Publisher Entra group `managed_application_operators` 
	- **Purpose**: Publisher managed services team members for manual operations and troubleshooting
	- **Members**: Human admins from publisher. Does not include any SPN. 
	- **Assigned roles on the managed app**
		- Contributor on the MRG - Full resource management (required for manual operations)
		- Automation Job Operator - Trigger runbooks on the managed app for troubleshooting
		- Key Vault Secrets Officer - Manage secrets during incidents (with customer-* prefix restriction by convention)
		- Write on Postgres SQL - Read-only database access for diagnostics
- Publisher SPN `managed_application_operator` 
	- **Purpose**: Automated publisher operations that trigger runbooks across tenants
	- **Assigned roles**
		- Member of `managed_application_operators` and inherits from group membership. 
		- On the publisher 
			- Automation Job Operator on publisher automation account - To trigger publisher runbooks. 
			- Log Analytics Contributor on customer LAW - For sending logs to publisher LAW.

---

### **1.2 Managed Application Identity**
User-Assigned Managed Identity: `vibedata-uami`
**Purpose:**
- Execute all automation runbooks within the managed application
- All bootstrap runbooks execute with this identity
- All mandatory runbooks execute with this identity
- Runbooks use Azure SDK with `DefaultAzureCredential` (automatically uses UAMI)
- Access automatically revoked when managed application deleted
- All operations logged to LAW with UAMI as actor

**Assigned Roles:**
- Key Vault Secrets Officer (Key Vault scope) - Manage all secrets
- Log Analytics Contributor (LAW scope) - Write logs and metrics
- Cost Management Reader (Subscription scope) - Read cost data
- Automation Job Operator (Automation Account scope) - Self-trigger runbooks
- AcrPull + AcrPush (ACR scope) - Import images from publisher ACR
- Storage Blob Data Contributor (Storage Account scope) - Manage artifacts
- PostgreSQL Flexible Server Administrator (PostgreSQL scope) - Full database access
- Contributor (MRG scope) - Manage all resources for Day-2 operations
- - Resource Graph Reader (Subscription scope) - Query resources during registry bootstrap

---

### **1.3 Customer Identity**<br>
Customer Entra User or Group provided during marketplace deployment as `adminObjectId` parameter
**Purpose**: Customer administrators can view resources and execute approved operations.
**Assigned Roles** (on MRG):
- Reader - View all resources and configurations
- Automation Job Operator - Execute runbooks

**Restrictions**:
- Cannot modify infrastructure resources directly (read-only)
- Cannot modify any secrets
- Cannot modify automation runbooks
- All write operations must go through approved runbooks

---

## **2 Audit and Compliance**
1. Data residency: Customer's Azure region
2. Data sovereignty: Customer's tenant (customer controls)
3. Encryption: Microsoft-managed keys
4. Audit: All identity operations logged to customer LAW:
	1. Publisher actions: Tagged with `managed_application_operator` SPN or user identity
	2. UAMI actions: Tagged with `vibedata-uami` identity
	3. Customer actions: Tagged with customer user/group identity
5. RBAC Scope Management

| Resource | vibedata-uami | Customer | Publisher Group | Publisher SPN |
|----------|---------------|----------|-----------------|---------------|
| MRG (overall) | Contributor | Reader | Contributor | Contributor (inherited) |
| Key Vault | Secrets Officer | None | Secrets Officer | Secrets Officer (inherited) |
| PostgreSQL | Admin | None | Reader | Reader (inherited) |
| Automation Account | Job Operator | Job Operator | Job Operator | Job Operator |
| ACR | Push + Pull | None | None | None |
| Storage Account | Blob Contributor | None | None | None |
| LAW | Contributor | None | None | Contributor (direct) |

