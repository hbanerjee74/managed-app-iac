---
notion_page_id: "2d5309d25a8c80068f27c475469f646d"
notion_numeric_id: 51
doc_id: "RFC-51"
notion_title: "Observability Standards"
source: "notion"
pulled_at: "2026-01-10T01:50:32Z"
type: "RFC"
root_prd_numeric_id: 30
linear_issue_id: "VD-69"
---

# 📜 Observability Standards

**RFC ID:** RFC-51  
**Status:** Accepted  
**Type:** Standard  
**Owning Team:** Assurance Agents

**URL:** https://www.notion.so/2d5309d25a8c80068f27c475469f646d

---

# Decision:
All VibeData managed applications implement a hybrid observability model: Azure resource logs flow to Log Analytics Workspace, Fabric workspace logs flow to customer Eventhouse, and alerts from both sources are processed through a unified event-driven architecture.

---

# Summary
Defines observability and alerting standards for VibeData managed applications.
- Azure Monitor handles infrastructure observability via LAW. Fabric Workspace Monitoring handles data platform observability via Eventhouse.
- Alerts from both sources flow through HTTP ingest endpoints to a unified queue-based processor.
- The Observability Service follows the at-least-once execution standard (RFC-72 Section 1) for reliable, idempotent alert processing operations.
- All operations are recorded to unified observability tables (`engineHistory` and `engineDlq`) per RFC-72.

---

# Context
- Managed applications require observability for both Azure infrastructure and Fabric data workloads.
- Azure resources emit logs via diagnostic settings to LAW.
- Fabric workspaces emit logs via Workspace Monitoring to Eventhouse.
- Alerts must be processed uniformly regardless of source.
- This RFC defines standards; implementation details for alert actions belong in Assurance Agent specifications.

---

# Proposal

## 1. Observability Architecture

### 1.1 Hybrid Model
| Domain | Log Destination | Alert Source |
|--------|-----------------|--------------|
| Azure Infrastructure | Log Analytics Workspace | Azure Monitor Alert Rules |
| Fabric Workspaces | Fabric Eventhouse (per data domain) | Data Activator |

### 1.2 Alert Flow
```plain text
Azure Monitor Alert → monitor-alert-ingest (HTTP) → monitor-alerts-queue → alert-processor
Data Activator Alert → fabric-alert-ingest (HTTP) → monitor-alerts-queue → alert-processor
```

---

## 2. Azure Infrastructure Observability

### 2.1 Diagnostic Settings
All Azure resources emit diagnostics per RFC-71 Section 19. Configuration applies to:
- All PaaS services in MRG
- All compute services (App Service, Functions, AKS)
- All data services (PostgreSQL, Storage, Key Vault)

### 2.2 Log Analytics Workspace
Configuration per RFC-71 Section 11.
| Setting | Value |
|---------|-------|
| SKU | PerGB2018 |
| Retention | 30 days |
| Daily Cap | None |

### 2.3 Custom Log Table
Single custom table for operational logging from VibeData services.

**Table:** `VibeData_Operations_CL`
| Column | Type | Description |
|--------|------|-------------|
| TimeGenerated | datetime | Event timestamp |
| Category | string | Log category: `health`, `update`, `hmac`, `tls`, `spn`, `alert` |
| CorrelationId | string | Request/job correlation ID |
| InstanceId | string | Managed app instance ID |
| ComponentId | string | Component ID (if applicable) |
| Operation | string | Operation name |
| Status | string | Succeeded, Failed, Pending |
| DurationMs | long | Operation duration in milliseconds |
| Message | string | Human-readable message |
| Details | dynamic | Additional structured data |

**Query Examples:**
```plain text
// Health check failures in last 24 hours
VibeData_Operations_CL
| where TimeGenerated > ago(24h)
| where Category == "health" and Status == "Failed"

// All operations for a correlation ID
VibeData_Operations_CL
| where CorrelationId == "abc-123"
| order by TimeGenerated asc

```

---

## 3. Fabric Workspace Observability

### 3.1 Workspace Monitoring
Fabric Workspace Monitoring is customer-enabled and emits logs to Eventhouse.
| Setting | Value |
|---------|-------|
| Destination | Customer Eventhouse |
| Retention | 30 days |
| Tables | ItemJobEventLogs, SemanticModelLogs |

### 3.2 Prerequisites for Data Domain Creation
During data domain pairing, VibeData validates that the Fabric workspace:
- has Workspace Monitoring enabled
- has an Eventhouse destination configured
- has a Data Activator alert rule with webhook pointing to `fabric-alert-ingest`

Results are used to bootstrap the registry under `dataDomains[].fabricWorkspace.monitoring` (RFC-45).

### 3.3 Data Activator Configuration
Data Activator monitors Eventhouse tables and triggers webhooks on alert conditions.
| Setting | Value |
|---------|-------|
| Trigger Source | Eventhouse (ItemJobEventLogs) |
| Action | HTTP webhook to `fabric-alert-ingest` |
| Payload | Standard Data Activator webhook format |

---

## 4. Azure Monitor Alert Rules

### 4.1 Alert Rule Categories
| Category | Scope | Examples |
|----------|-------|----------|
| Infrastructure | Azure resources | CPU > 80%, Memory > 85%, Disk > 90% |
| Application | App Service, Functions | HTTP 5xx rate, Response time |
| Data | PostgreSQL, Storage | Connection failures, Throttling |
| Security | Key Vault | Access denied, Secret expiry |

### 4.2 Alert Rule Configuration
| Setting | Value |
|---------|-------|
| Action Group | `vibedata-alerts-ag` |
| Action Type | Webhook |
| Webhook URI | `https://{fqdn}/api/alerts/azure` |
| Severity Mapping | Sev0-1 → Critical, Sev2 → Warning, Sev3-4 → Info |

### 4.3 Common Schema
All Azure Monitor alerts use Common Alert Schema for consistent parsing.

---

## 5. Alert Processing Architecture

**Execution Standard:** The Observability Service follows the at-least-once execution standard defined in RFC-72 Section 1. This ensures reliable alert processing through standardized retry handling, dead-letter queue management, and operation history tracking.

### 5.1 Components
Three Azure Functions handle alert ingestion and processing:
| Function | Trigger | Purpose |
|----------|---------|---------|
| `monitor-alert-ingest` | HTTP | Receives Azure Monitor webhooks |
| `fabric-alert-ingest` | HTTP | Receives Data Activator webhooks |
| `alert-processor` | Queue | Processes alerts from queue |

All functions deployed per RFC-42 Section 4.3 as containerized workloads.

### 5.2 HTTP Ingest Functions

**monitor-alert-ingest:**
1. Receive Azure Monitor webhook (Common Alert Schema)
2. Validate payload structure
3. Transform to queue message format
4. Enqueue to `monitor-alerts-queue`
5. Return HTTP 200

**fabric-alert-ingest:**
1. Receive Data Activator webhook
2. Validate payload structure
3. Transform to queue message format
4. Enqueue to `monitor-alerts-queue`
5. Return HTTP 200

### 5.3 Queue Message Schema
```json
{
  "messageId": "uuid",
  "source": "AzureMonitor | FabricDataActivator",
  "receivedAtUtc": "ISO-8601",
  "severity": "Critical | Warning | Info",
  "alertRule": "rule-name",
  "resourceId": "azure-resource-id or fabric-item-id",
  "description": "Alert description",
  "payload": {}
}
```

### 5.4 Alert Processing Design
- Messages are processed asynchronously via queue-triggered function → durable function pattern per RFC-72 Section 1.2
- Queue-triggered function checks message retry count (`dequeueCount`) and If retry count exceeded then its sent to DLQ and the message is deleted.
- Retry logic, DLQ management, and failure handling follow RFC-72 Section 1.7 patterns

---

## 6. Storage Resources

### 6.1 Queue
Per RFC-42 Section 9.2:
| Queue | Purpose |
|-------|---------|
| `monitor-alerts-queue` | Alert messages from both sources |

### 6.2 Tables
Per RFC-42 Section 9.3:
| Table | Purpose |
|-------|---------|
| `alertsHistory` | Processed alert records |

---

## 7. API Surface

### 7.1 Alert Ingest Endpoints
| Method | Path | Purpose |
|--------|------|---------|
| POST | /api/alerts/azure | Azure Monitor webhook endpoint |
| POST | /api/alerts/fabric | Data Activator webhook endpoint |

### 7.2 Alert Query Endpoints
| Method | Path | Purpose |
|--------|------|---------|
| GET | /api/alerts | List recent alerts |

---

# Impact
None

---

# Open Questions
None.
