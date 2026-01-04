# 📜 Unified Engine Tables (DLQ and History)

**RFC ID:** RFC-72  
**Status:** In Review  
**Type:** Standard  
**Owning Team:** Platform

**URL:** https://www.notion.so/2dc309d25a8c8093abe3e76201f6c530

---

# Decision:
All engine operations use unified tables per deployment context:
- Publisher: `engineDlq` and `engineHistory` tables
- Managed App: `engineDlq` and `engineHistory` tables

---

# Summary
Defines unified table schemas and APIs for dead letter queue (DLQ) and operation history across all VibeData engines.

---

# Context
- Multiple engines (Provisioning, HMAC, TLS, SPN, Update, Health, Alerts) each had dedicated DLQ and history tables.
- This created 9 DLQ tables and 8 history tables across Publisher and Managed App contexts.
- Unified tables reduce operational overhead, simplify monitoring, and provide consistent API patterns.
- Azure Table Storage PartitionKey enables efficient per-engine queries while sharing infrastructure.

---

# Proposal
## 1. Unified DLQ Table
### 1.1 Schema
| Field | Type | Description |
|-------|------|-------------|
| PartitionKey | string | Engine name |
| RowKey | string | `{instanceId}-{timestamp}` or `{messageId}-{timestamp}` |
| Engine | string | Engine identifier (redundant for queries) |
| InstanceId | string | Target instance ID (`publisher` for publisher-scoped operations) |
| OriginalQueue | string | Source queue name |
| OriginalMessage | string (JSON) | Original message payload |
| ErrorMessage | string | Failure reason |
| DequeueCount | int | Number of processing attempts |
| FirstFailureAtUtc | datetime | Initial failure timestamp |
| LastFailureAtUtc | datetime | Most recent failure timestamp |
| Status | string | `Pending`, `Resolved`, `Expired` |
| ResolutionNotes | string | Notes when resolved (nullable) |
| ResolvedAtUtc | datetime | Resolution timestamp (nullable) |
| ResolvedBy | string | Identity that resolved (nullable) |
| CorrelationId | string | Correlation ID for tracing |

### 1.2 Engine Values
**Publisher `engineDlq`:**

| Engine | OriginalQueue | Description |
|--------|---------------|-------------|
| `provisioning` | `webhook-queue` | Failed marketplace notifications |
| `hmac` | `hmac-rotation-queue` | Failed HMAC rotations |
| `tls` | `tls-rotation-queue` | Failed TLS distributions |
| `spn` | `spn-rotation-queue` | Failed SPN rotations |
| `update-publisher` | N/A | Failed update notifications |
| `alerts` | `monitor-alerts-queue` | Failed alert processing |

**Managed App `engineDlq`:**

| Engine | OriginalQueue | Description |
|--------|---------------|-------------|
| `update` | `update-notifications-queue` | Failed component updates |
| `health` | `health-notifications-queue` | Failed health orchestrations |
| `alerts` | `monitor-alerts-queue` | Failed alert processing |

### 1.3 DLQ Retention
| Status | Retention |
|--------|-----------|
| Pending | Indefinite (requires resolution) |
| Resolved | 90 days |
| Expired | 90 days |

Cleanup via scheduled function using `ResolvedAtUtc < now() - 90 days` or `Status = Expired AND LastFailureAtUtc < now() - 90 days`.

---

## 2. DLQ API Surface
### 2.1 Endpoints
| Method | Path | Input | Purpose |
|--------|------|-------|---------|
| GET | /api/dlq | engine?, status?, instanceId?, fromDate?, toDate?, limit?, continuationToken? | List DLQ messages |
| GET | /api/dlq/{engine}/{rowKey} | engine, rowKey | Get message details |
| PATCH | /api/dlq/{engine}/{rowKey} | engine, rowKey, status, resolutionNotes | Update message status |
| POST | /api/dlq/{engine}/{rowKey}/retry | engine, rowKey | Re-enqueue to original queue |
| POST | /api/dlq/expire | olderThanDays, engine? | Bulk expire old messages |

### 2.2 Query Parameters
| Parameter | Type | Description |
|-----------|------|-------------|
| engine | string | Filter by engine (PartitionKey) |
| status | string | Filter by status (`Pending`, `Resolved`, `Expired`) |
| instanceId | string | Filter by instance |
| fromDate | datetime | Filter messages after date |
| toDate | datetime | Filter messages before date |
| limit | int | Max results (default 50, max 100) |
| continuationToken | string | Pagination token |

### 2.3 Response Schema
```json
{
  "status": "Succeeded",
  "correlationId": "...",
  "timestamp": "...",
  "data": {
    "items": [
      {
        "engine": "hmac",
        "rowKey": "...",
        "instanceId": "...",
        "originalQueue": "hmac-rotation-queue",
        "errorMessage": "...",
        "dequeueCount": 5,
        "status": "Pending",
        "firstFailureAtUtc": "...",
        "lastFailureAtUtc": "...",
        "correlationId": "..."
      }
    ],
    "continuationToken": "..."
  }
}
```

### 2.4 Retry Behavior
`POST /api/dlq/{engine}/{rowKey}/retry`:
1. Read message from DLQ
2. Re-enqueue to `OriginalQueue`
3. Update DLQ status to `Resolved` with note "Retried"
4. Return new queue message ID

---

## 3. Unified History Table
### 3.1 Schema
| Field | Type | Description |
|-------|------|-------------|
| PartitionKey | string | Engine name |
| RowKey | string | `{correlationId}-{timestamp}` |
| Engine | string | Engine identifier (redundant for queries) |
| InstanceId | string | Target instance ID (`publisher` for publisher-scoped) |
| Operation | string | Operation name |
| Status | string | `Succeeded`, `Failed` |
| DurationMs | long | Operation duration in milliseconds |
| Input | string (JSON) | Operation input parameters |
| Output | string (JSON) | Operation output (nullable) |
| Error | string | Error message if failed (nullable) |
| CreatedAtUtc | datetime | Operation timestamp |
| CorrelationId | string | Correlation ID for tracing |

### 3.2 Engine Values
**Publisher `engineHistory`:**

| Engine | Operations |
|--------|------------|
| `provisioning` | `webhook-received`, `instance-registered`, `bootstrap-complete` |
| `hmac` | `rotate`, `notify` |
| `tls` | `renew`, `distribute` |
| `spn` | `rotate` |
| `update-publisher` | `evaluate`, `notify` |
| `alerts` | `process` |

**Managed App `engineHistory`:**

| Engine | Operations |
|--------|------------|
| `update` | `process`, `component-update` |
| `health` | `check`, `aggregate` |
| `alerts` | `process` |

### 3.3 History Retention
| Status | Retention |
|--------|-----------|
| All | 90 days |

Cleanup via scheduled function using `CreatedAtUtc < now() - 90 days`.

---

## 4. History API Surface
### 4.1 Endpoints
| Method | Path | Input | Purpose |
|--------|------|-------|---------|
| GET | /api/history | engine?, instanceId?, status?, operation?, fromDate?, toDate?, correlationId?, limit?, continuationToken? | List history entries |
| GET | /api/history/{engine}/{rowKey} | engine, rowKey | Get entry details |

### 4.2 Query Parameters
| Parameter | Type | Description |
|-----------|------|-------------|
| engine | string | Filter by engine (PartitionKey) |
| instanceId | string | Filter by instance |
| status | string | Filter by status (`Succeeded`, `Failed`) |
| operation | string | Filter by operation type |
| fromDate | datetime | Filter entries after date |
| toDate | datetime | Filter entries before date |
| correlationId | string | Filter by correlation ID |
| limit | int | Max results (default 50, max 100) |
| continuationToken | string | Pagination token |

### 4.3 Response Schema
```json
{
  "status": "Succeeded",
  "correlationId": "...",
  "timestamp": "...",
  "data": {
    "items": [
      {
        "engine": "hmac",
        "rowKey": "...",
        "instanceId": "...",
        "operation": "rotate",
        "status": "Succeeded",
        "durationMs": 1234,
        "createdAtUtc": "...",
        "correlationId": "..."
      }
    ],
    "continuationToken": "..."
  }
}
```

---

## 5. Registry Configuration
### 5.1 Publisher Registry (RFC-54)
Add to root schema:
```json
"engineTablesConfig": {
  "storageAccountName": "...",
  "dlqTableName": "engineDlq",
  "historyTableName": "engineHistory",
  "retentionDays": 90
}
```

### 5.2 Managed App Registry (RFC-45)
Add to root schema:
```json
"engineTablesConfig": {
  "storageAccountName": "...",
  "dlqTableName": "engineDlq",
  "historyTableName": "engineHistory",
  "retentionDays": 90
}
```

---

## 6. Engine Integration Pattern
### 6.1 Writing to DLQ
When an engine exhausts retries:
```python
# After max retries exceeded
dlq_entry = {
    "PartitionKey": engine_name,  # e.g., "hmac"
    "RowKey": f"{instance_id}-{timestamp}",
    "Engine": engine_name,
    "InstanceId": instance_id,
    "OriginalQueue": queue_name,
    "OriginalMessage": json.dumps(message),
    "ErrorMessage": error_message,
    "DequeueCount": dequeue_count,
    "FirstFailureAtUtc": first_failure,
    "LastFailureAtUtc": datetime.utcnow(),
    "Status": "Pending",
    "CorrelationId": correlation_id
}
table_client.create_entity(dlq_entry)
queue_client.delete_message(message)
```

### 6.2 Writing to History
After each operation completes:
```python
history_entry = {
    "PartitionKey": engine_name,  # e.g., "hmac"
    "RowKey": f"{correlation_id}-{timestamp}",
    "Engine": engine_name,
    "InstanceId": instance_id,
    "Operation": operation_name,
    "Status": "Succeeded" if success else "Failed",
    "DurationMs": duration_ms,
    "Input": json.dumps(input_params),
    "Output": json.dumps(output) if output else None,
    "Error": error_message if not success else None,
    "CreatedAtUtc": datetime.utcnow(),
    "CorrelationId": correlation_id
}
table_client.create_entity(history_entry)
```

---

# Impact
| Document | Change |
|----------|-------|
| RFC-42 | Update storage tables: remove per-engine tables, add `engineDlq`, `engineHistory` |
| RFC-45 | Add `engineTablesConfig` to schema |
| RFC-51 | Replace `alertsHistory`, `alertsDlq` with unified tables |
| RFC-54 | Add `engineTablesConfig` to schema |
| RFC-57 | Update storage tables list |
| RFC-70 | Add Section 12 for unified DLQ/History API pattern |

---

# Open Questions
None.

