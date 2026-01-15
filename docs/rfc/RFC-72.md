---
notion_page_id: "2dc309d25a8c8093abe3e76201f6c530"
notion_numeric_id: 72
doc_id: "RFC-72"
notion_title: "Engine operations standard (At least once execution)"
source: "notion"
pulled_at: "2026-01-09T23:48:12Z"
type: "RFC"
root_prd_numeric_id: 30
linear_issue_id: "VD-69"
---

# 📜 Engine Operations Standard (Unified Tables and At-Least-Once Execution)

**RFC ID:** RFC-72  
**Status:** In Review  
**Type:** Standard  
**Owning Team:** Platform

**URL:** https://www.notion.so/2dc309d25a8c8093abe3e76201f6c530

---

# Decision:
All long-running platform tasks follow a standardized execution pattern with unified operational tables:

**Unified Tables:**
- Publisher: `engineDlq` and `engineHistory` tables
- Managed App: `engineDlq` and `engineHistory` tables

**At-Least-Once Execution Standard:**
- All engines use queue-triggered Azure Functions → retry check → Azure Durable Functions pattern
- Idempotency guaranteed through correlation IDs and durable function state
- Failed messages moved to unified DLQ after max retry attempts
- All operations recorded to unified history table

---

# Summary
Defines two complementary standards for VibeData engine operations:

1. **Unified Table Schemas and APIs**: Standardized dead letter queue (DLQ) and operation history tables shared across all engines, reducing operational overhead and enabling consistent monitoring.

2. **At-Least-Once Execution Standard**: Standardized execution pattern for long-running platform tasks requiring idempotency and reliable delivery guarantees. Uses queue-triggered Azure Functions with retry logic and Azure Durable Functions for orchestration.

Together, these standards ensure reliable, observable, and maintainable engine operations across Publisher and Managed App contexts.

---

# Context

**Unified Tables Context:**
- Multiple engines (Provisioning, HMAC, TLS, SPN, Update, Health, Alerts) each had dedicated DLQ and history tables.
- This created 9 DLQ tables and 8 history tables across Publisher and Managed App contexts.
- Unified tables reduce operational overhead, simplify monitoring, and provide consistent API patterns.
- Azure Table Storage PartitionKey enables efficient per-engine queries while sharing infrastructure.

**At-Least-Once Execution Standard Context:**
- Long-running platform tasks require idempotency and at-least-once delivery guarantees to handle transient failures and ensure reliable execution.
- Each engine was implementing similar retry, DLQ, and history recording logic independently, leading to inconsistent patterns and operational complexity.
- Azure Storage Queues provide at-least-once delivery semantics, requiring idempotent processing on the consumer side.
- Azure Durable Functions provide built-in orchestration state management and idempotency guarantees, making them ideal for long-running tasks.
- Standardizing the execution pattern (queue-triggered function → retry check → durable function) ensures consistent error handling, retry logic, and operational observability across all engines.

---

# Proposal
The following services require the at-least-once execution standard due to their critical nature and need for idempotency:

**Publisher Services:**

- **Provisioning Engine** (RFC-55): Processes marketplace webhook notifications for instance provisioning. Requires idempotency to prevent duplicate provisioning and reliable delivery to ensure all marketplace events are processed even during transient failures.

- **Update Engine** (RFC-44): Handles publisher-side update notifications and evaluations. Needs at-least-once delivery to ensure update availability checks complete reliably, with idempotency to prevent duplicate update processing.

- **HMAC Rotation Engine** (RFC-53): Rotates HMAC keys on schedule. Requires idempotency to prevent duplicate rotations and reliable delivery to ensure rotation tasks complete even if the function fails mid-execution.

- **TLS Key Rotation Engine** (RFC-62): Renews and distributes TLS certificates. Needs reliable delivery to ensure certificate renewals complete and idempotency to prevent duplicate certificate generation or distribution.

- **SPN Secret Rotation Engine** (RFC-69): Rotates Service Principal secrets. Requires idempotency to prevent duplicate secret rotations and reliable delivery to ensure secrets are rotated even during transient failures.

- **Observability Service** (RFC-51): Processes alerts from Azure Monitor and Fabric Data Activator. Needs reliable delivery to ensure all alerts are processed and idempotency to prevent duplicate alert processing or notifications.

**Managed App Services:**

- **Update Service** (RFC-44, Managed App portion): Processes component update notifications and orchestrates updates. Requires idempotency to prevent duplicate update operations and reliable delivery to ensure updates complete even if the orchestrator fails.

- **Health Service** (RFC-52): Performs scheduled health checks on all components (timer-triggered variation). Uses durable function singleton pattern for orchestration; orchestrator failures require DLQ handling. Needs idempotency to prevent duplicate health checks and reliable execution to ensure health status is always current.

All these services benefit from:
- **Idempotency**: Prevents duplicate operations that could cause data corruption or resource conflicts
- **Reliable Delivery**: Ensures critical platform operations complete even during transient failures
- **Observability**: Unified history and DLQ tables enable consistent monitoring and troubleshooting across all engines
- **Operational Consistency**: Standardized patterns reduce operational complexity and enable shared tooling

---

## 1. At-Least-Once Execution Standard

All long-running platform tasks that require idempotency and at-least-once delivery guarantees follow a standardized execution pattern. This standard ensures reliable processing of messages with proper retry handling, dead-letter queue management, and operation history tracking.

### 1.1 Architecture Pattern

Each engine implements the following three-component architecture:

1. **Queue**: Azure Storage Queue specific to the engine (e.g., `hmac-rotation-queue`, `update-notifications-queue`)
2. **Queue-Triggered Azure Function**: Handles incoming messages from the queue
3. **Azure Durable Function**: Executes the actual long-running task with orchestration capabilities

### 1.2 Execution Flow

**Standard Queue-Triggered Pattern:**
```plain text
Message arrives in queue
    ↓
Queue-triggered function receives message
    ↓
Check message retry count (dequeueCount)
    ↓
If retry count exceeded → Write to DLQ (Section 2.1) → Delete message → Exit
    ↓
Otherwise → Call Azure Durable Function orchestrator
    ↓
Durable Function executes task (with idempotency guarantees)
    ↓
On completion → Write to history table (Section 4.1)
    ↓
Delete message from queue
```

**Singleton Pattern (for engines modifying registry):**
```plain text
Message arrives in queue (or timer triggers)
    ↓
Queue/timer-triggered function receives message
    ↓
Check message retry count (dequeueCount) [if queue-triggered]
    ↓
If retry count exceeded → Write to DLQ (Section 2.1) → Exit
    ↓
Check registry lock (instanceLock) → 409 Conflict if locked
    ↓
Call Azure Durable Function orchestrator
    ↓
Check Durable Function singleton → 409 Conflict if duplicate instanceId
    ↓
Acquire registry lock (CAS) → Set lockJobId and lockUntilUtc
    ↓
Durable Function executes task (modifies registry state)
    ↓
On completion → Write to history table (Section 4.1)
    ↓
Release registry lock in finally block
    ↓
Delete message from queue [if queue-triggered]
```

### 1.3 Retry and DLQ Handling

The queue-triggered function implements retry logic:

1. **Read message**: Dequeue message from engine-specific queue
2. **Check retry count**: Inspect `dequeueCount` property
3. **If `dequeueCount >= maxRetryAttempts`**:
   - Write entry to unified `engineDlq` table per Section 2.1
   - Include `OriginalQueue`, `OriginalMessage`, `ErrorMessage`, `DequeueCount`, timestamps
   - Delete message from queue
   - Exit (do not call durable function)
4. **If `dequeueCount < maxRetryAttempts`**:
   - Call Azure Durable Function orchestrator with message payload
   - Let Azure Functions retry mechanism handle transient failures
   - On success: write to history table and delete message
   - On failure: message remains in queue for retry (Azure Functions handles visibility timeout)

### 1.4 Idempotency Requirements

All engines must implement idempotent operations:

- **Correlation ID**: Each message includes a unique `correlationId` used for deduplication
- **Durable Function State**: Azure Durable Functions provide built-in idempotency through orchestration state
- **Idempotent Operations**: Engine-specific operations must be idempotent (e.g., checking if rotation already completed before rotating)
- **History Lookup**: Before executing, check `engineHistory` table for existing successful operation with same `correlationId`
- **Singleton Pattern**: Engines modifying registry state use singleton pattern (Section 1.8) to prevent concurrent execution and ensure idempotent registry updates

### 1.5 Per-Engine Pattern

Each engine follows this pattern independently:

| Component | Pattern |
|-----------|--------|
| Queue | Engine-specific queue (e.g., `{engine}-queue`) |
| Queue Function | Engine specific queue trigger Azure Function (e.g. `{engine}-queue-trigger` ) |
| Durable Function | Engine specific Azure Durable Function (`{engine}-orchestrator` ) |
| DLQ Table | Unified `engineDlq` (PartitionKey = engine name) |
| History Table | Unified `engineHistory` (PartitionKey = engine name) |

**Singleton Pattern Usage:**
- **Required**: Engines that modify registry state (Health Service, Update Service)
- **Optional**: Engines that don't modify registry can use standard pattern without registry locking
- **Timer-Triggered Engines**: Health Service uses timer-triggered durable function with singleton pattern (variation of standard queue-triggered pattern)

### 1.6 History Recording

After each operation completes (success or failure):

1. **On Success**: Write entry to `engineHistory` with `Status = "Succeeded"`, operation details, duration, output
2. **On Failure**: Write entry to `engineHistory` with `Status = "Failed"`, error message, duration
3. **Correlation ID**: Use the same `correlationId` from the original message for traceability

### 1.7 Error Handling

- **Transient Failures**: Handled by Azure Functions retry mechanism (message remains in queue)
- **Permanent Failures**: After `maxRetryAttempts`, message moved to DLQ for manual intervention
- **Orchestrator Failures**: Durable Function failures are retried by Azure Functions; if orchestrator itself fails after max retries, write to DLQ

### 1.8 Singleton Pattern and Registry Locking

Any engine that modifies registry state prevents concurrent execution using a two-layer singleton pattern.

**Layer 1: Azure Durable Functions Singleton Pattern**
- Uses Azure Durable Functions singleton pattern to ensure only one orchestrator instance runs per scope
-  `instanceId = {functionName}-{tenantId}` or `instanceId = {functionName}-{instanceId}` ensures uniqueness
- If another instance with the same ID is running → return `409 Conflict`
- Provides built-in Azure Functions-level mutual exclusion

**Layer 2: Registry-Level Lock (CAS-based)**
- Registry lock prevents concurrent modifications to registry state
- Lock structure (per RFC-45 Section 4 and RFC-54):
```json
"instanceLock": {     
    "lockJobId": "",              // Unique identifier for lock holder     
    "lockDurationSeconds": 3600,  // Lock duration (default 1 hour)     
    "lockUntilUtc": ""            // Expiration timestamp   
}
```

- Lock acquisition MUST use atomic Compare-And-Set (CAS) via `registryVersion`
- Lock acquisition fails if valid lock exists (`lockJobId` is set and `lockUntilUtc` hasn't expired)
- Only the lock holder (matching `lockJobId` and unexpired `lockUntilUtc`) can modify the registry
- Lock MUST be released in a `finally` block to ensure cleanup on errors

**Singleton Pattern Execution Flow:**
```plain text
1. Check if instanceLock exists → 409 Conflict if locked
2. Create orchestrator run
3. Check Durable Function singleton → 409 Conflict if duplicate instanceId
4. Acquire registry lock (CAS operation via registryVersion)
   - Set lockJobId = jobId
   - Set lockUntilUtc = now() + lockDurationSeconds
5. Execute operations (modify registry state)
6. Release lock in finally block (always executes)
   - Clear lockJobId and lockUntilUtc
```

**Benefits:**
- **Prevents Race Conditions**: Ensures only one operation modifies registry at a time
- **Consistency**: Prevents lost updates and inconsistent registry state
- **Automatic Expiration**: `lockUntilUtc` provides safety if orchestrator crashes without releasing lock
- **Idempotent Lock Acquisition**: CAS ensures only one process acquires the lock

**Registry Lock References:**
- Managed App Registry: RFC-45 Section 4 (Registry Lock)
- Publisher Registry: RFC-54 (instanceLock in instance schema)

---

## 2. Unified DLQ Table
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

## 3. DLQ API Surface
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

## 4. Unified History Table
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

## 5. History API Surface
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

## 6. Registry Configuration
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

# Impact

## Unified Tables Impact
| Document | Change |
|----------|-------|
| RFC-42 | Update storage tables: remove per-engine tables, add `engineDlq`, `engineHistory` |
| RFC-45 | Add `engineTablesConfig` to schema |
| RFC-51 | Replace `alertsHistory`, `alertsDlq` with unified tables |
| RFC-54 | Add `engineTablesConfig` to schema |
| RFC-57 | Update storage tables list |
| RFC-70 | Add Section 12 for unified DLQ/History API pattern |

## At-Least-Once Execution Standard Impact

The following engines use the at-least-once execution standard defined in Section 1:

**Publisher Engines:**
- **Provisioning Engine** (RFC-55): Uses `webhook-queue`, queue-triggered function, and durable function for marketplace provisioning tasks
- **Update Engine** (RFC-44): Uses queue-triggered function and durable function for publisher-side update notifications
- **HMAC Rotation Engine** (RFC-53): Uses `hmac-rotation-queue`, queue-triggered function, and durable function for HMAC key rotations
- **TLS Key Rotation Engine** (RFC-62): Uses `tls-rotation-queue`, queue-triggered function, and durable function for TLS certificate rotations
- **SPN Secret Rotation Engine** (RFC-69): Uses `spn-rotation-queue`, queue-triggered function, and durable function for SPN secret rotations
- **Observability Service** (RFC-51): Uses `monitor-alerts-queue`, `alert-processor` queue-triggered function, and durable function for alert processing

**Managed App Engines:**
- **Update Service** (RFC-44, Managed App portion): Uses `update-notifications-queue`, queue-triggered function, and durable function for component updates
- **Health Service** (RFC-52): Uses timer-triggered durable function (singleton pattern) for health checks; orchestrator failures use DLQ per Section 1.7

All these engines must:
- Implement the queue-triggered → retry check → durable function pattern
- Use unified `engineDlq` and `engineHistory` tables per deployment context
- Ensure idempotency through correlation IDs and durable function state
- Record all operations to history table
- Move failed messages to DLQ after max retry attempts

---

# Open Questions

1. **Retry Configuration Standardization**: Should `maxRetryAttempts` be standardized across all engines, or should each engine define its own retry policy? What are the recommended retry counts for different operation types?

2. **Correlation ID Generation**: Should correlation IDs be generated by the message producer, the queue-triggered function, or the durable function? What format should be used (UUID, timestamp-based, etc.)?

3. **DLQ Resolution Workflow**: What is the standard process for resolving DLQ messages? Should there be automated retry mechanisms, or is manual intervention always required?

4. **History Table Query Patterns**: Are there common query patterns across engines that should be optimized? Should we add additional indexes or composite keys?

5. **Durable Function Timeout Handling**: How should orchestrator timeouts be handled? Should long-running orchestrations be split into multiple shorter orchestrations?

6. **Cross-Engine Correlation**: Should correlation IDs be shared across engines for multi-engine workflows (e.g., provisioning → update → health check)? How do we trace operations across engines?

7. **Idempotency Key Selection**: Beyond correlation IDs, what other fields should be used for idempotency checks? Should engines check history table before execution, or rely solely on durable function state?

8. **Monitoring and Alerting**: What metrics should be standardized across all engines (e.g., DLQ message count, average processing time, retry rate)? Should there be unified dashboards?

9. **Message Schema Standardization**: Should all queue messages follow a common schema format, or can engines define their own schemas? What are the minimum required fields?

10. **Graceful Degradation**: How should engines handle partial failures (e.g., history write succeeds but DLQ write fails)? What is the fallback strategy?

