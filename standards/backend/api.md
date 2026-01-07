# API Standards

Approver: Umesh Kakkad
Owning Team: Platform
Created by: Hemanta Banerjee
Reviewers: Shwetank Sheel
Status: In Review
Type: Standard
ID: RFC-70
PRDs: SPN Secret Rotation Engine (https://www.notion.so/SPN-Secret-Rotation-Engine-2da309d25a8c808aa771eb883ca1f09f?pvs=21), Update Engine (https://www.notion.so/Update-Engine-2da309d25a8c80738874dc01fe245224?pvs=21), TLS Certificate Rotation Engine (https://www.notion.so/TLS-Certificate-Rotation-Engine-2da309d25a8c80ada0e6db3358520625?pvs=21), HMAC Rotation Engine (https://www.notion.so/HMAC-Rotation-Engine-2da309d25a8c80ebbe0ef38fb12ec3ca?pvs=21), Provisioning Engine (https://www.notion.so/Provisioning-Engine-2da309d25a8c802a8ef9d47f388270d8?pvs=21), Health Service (https://www.notion.so/Health-Service-2da309d25a8c80628dbefb0d7023821e?pvs=21), AKS and Airbyte Deployment (https://www.notion.so/AKS-and-Airbyte-Deployment-2da309d25a8c80b5ae8ddaf0f4e2a6a8?pvs=21), Publisher Day-2 Operations (https://www.notion.so/Publisher-Day-2-Operations-2d9309d25a8c80b199bde32e0dd1ef84?pvs=21)
Authors: Hemanta Banerjee
Github Repo: vd-common

# Decision:

All VibeData APIs use HMAC authentication for service-to-service calls and Entra ID bearer token for user-to-API calls, with correlation ID tracing and a consistent response envelope.

---

# Summary

Defines the standard API contract for all VibeData publisher and managed application APIs, including request headers, response envelope, error codes, and authentication requirements.

---

# Context

- Multiple services expose APIs (Provisioning Engine, Update Engine, HMAC Rotation, TLS Rotation, SPN Rotation, Health Service)
- Consistent API contract required for maintainability and client integration
- Common patterns (correlation, error handling, authentication) should not be repeated across RFCs/PRDs

---

# Proposal
- **RESTful Design**: Follow REST principles with clear resource-based URLs and appropriate HTTP methods (GET, POST, PUT, PATCH, DELETE)
- **Consistent Naming**: Use consistent, lowercase, hyphenated or underscored naming conventions for endpoints across the API
- **Versioning**: Implement API versioning strategy (URL path or headers) to manage breaking changes without disrupting existing clients
- **Plural Nouns**: Use plural nouns for resource endpoints (e.g., `/users`, `/products`) for consistency
- **Nested Resources**: Limit nesting depth to 2-3 levels maximum to keep URLs readable and maintainable
- **Query Parameters**: Use query parameters for filtering, sorting, pagination, and search rather than creating separate endpoints
- **HTTP Status Codes**: Return appropriate, consistent HTTP status codes that accurately reflect the response (200, 201, 400, 404, 500, etc.)
- **Rate Limiting Headers**: Include rate limit information in response headers to help clients manage their usage

Below are speicfic guidelines:
## 1. Request Headers

| Header | Required | Description |
| --- | --- | --- |
| `Authorization` | Yes | Authentication token (Entra ID bearer token or HMAC signature) |
| `X-Correlation-Id` | No | UUID for request tracing; auto-generated if not provided |
| `Content-Type` | Conditional | `application/json` for requests with body |

---

## 2. Response Envelope

All API responses use a standard envelope:

```json
{
  "status": "Succeeded | Failed",
  "correlationId": "uuid",
  "timestamp": "ISO-8601 UTC",
  "data": {},
  "error": {}
}

```

| Field | Present | Description |
| --- | --- | --- |
| `status` | Always | Operation outcome |
| `correlationId` | Always | Request correlation ID (from header or generated) |
| `timestamp` | Always | Response timestamp in UTC |
| `data` | On success | Operation-specific response payload |
| `error` | On failure | Error details |

---

## 3. Error Response

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "target": "field or resource",
    "details": []
  }
}

```

---

## 4. Standard Error Codes

| HTTP Code | Error Code | Condition |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Invalid input parameters |
| 401 | `AUTHENTICATION_FAILED` | Missing or invalid credentials |
| 403 | `AUTHORIZATION_FAILED` | Insufficient permissions |
| 404 | `RESOURCE_NOT_FOUND` | Requested resource does not exist |
| 409 | `CONFLICT` | Operation conflicts with current state (e.g., lock held, operation in progress) |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Unexpected server error |
| 503 | `SERVICE_UNAVAILABLE` | Service temporarily unavailable (e.g., registry not initialized) |

---

## 5. Authentication

### 5.1 Entra ID (Publisher APIs)

- Bearer token in `Authorization` header
- Token validated against publisher Entra ID tenant
- Used for: MST-initiated operations, publisher-to-publisher calls

### 5.2 HMAC (Cross-Tenant APIs)

- Signature in `X-Signature` header, timestamp in `X-Timestamp` header
- Per RFC-53
- Used for: Publisher-to-managed-app calls, managed-app-to-publisher calls

---

## 6. Pagination

For list endpoints returning multiple items:

**Request Parameters:**

| Parameter | Type | Description |
| --- | --- | --- |
| `limit` | integer | Maximum items to return (default: 50, max: 100) |
| `continuationToken` | string | Token from previous response for next page |

**Response:**

| Field | Description |
| --- | --- |
| `items` | Array of results |
| `continuationToken` | Token for next page (null if no more results) |

---

## 7. Filtering

For endpoints supporting filters:

| Parameter | Type | Description |
| --- | --- | --- |
| `status` | string | Filter by status value |
| `fromDate` | ISO-8601 | Filter items created/updated after this date |
| `toDate` | ISO-8601 | Filter items created/updated before this date |

---

## 8. Idempotency

- All mutating operations (POST, PUT, PATCH, DELETE) must be idempotent
- Clients may retry failed requests safely
- Services must handle duplicate requests without side effects

---

## 9. Retry Policy

Clients should implement retry for transient failures:

| Error Code | Retry |
| --- | --- |
| 429 | Yes, with backoff per `Retry-After` header |
| 500 | Yes, with exponential backoff |
| 503 | Yes, with exponential backoff |
| 4xx (other) | No |

---

## 10. HTTP Method Usage

### 10.1 Method Selection

| Method | Purpose | Idempotent | Request Body |
| --- | --- | --- | --- |
| GET | Read resource(s) | Yes | No |
| POST | Create resource OR trigger action | No* | Optional |
| PATCH | Partial update to existing resource | No | Yes |
| DELETE | Remove resource | Yes | No |
- POST is idempotent when operation uses idempotency key or is inherently safe to retry.

### 10.2 Path Design Rules

1. **No verbs in paths** — HTTP method conveys the action
    - ✗ `POST /instances/{id}/hmac/rotate`
    - ✓ `POST /api/instances/{id}/hmac`
2. **Same path, different methods** — Read vs trigger on same resource
    - `GET /api/instances/{id}/health` → read health status
    - `POST /api/instances/{id}/health` → trigger health check
3. **Partial updates use PATCH** — Not POST with action suffix
    - ✗ `POST /dlq/{rowKey}/processed`
    - ✓ `PATCH /api/spn/dlq/{rowKey}` with body `{ "status": "Processed", ... }`
4. **Bulk actions use POST with action noun** — Exception for batch operations affecting multiple resources
    - `POST /api/dlq/expire` with body `{ "olderThanDays": 30 }`
    - `POST /api/updates/evaluate` (triggers evaluation across all instances)

### 10.3 Standard Resource Patterns

**Resource Status:**

```
GET   /api/{domain}/{id}         → Read status
POST  /api/{domain}/{id}         → Trigger action (if applicable)
PATCH /api/{domain}/{id}         → Update settings

```

**Policy Configuration:**

```
GET   /api/{domain}/{id}/policy      → Read policy
PATCH /api/{domain}/{id}/policy      → Update policy (partial)

```

---

## 11. PRD API Table Format

All PRDs must specify APIs with explicit HTTP method and path:

| Method | Path | Input | Purpose |
| --- | --- | --- | --- |
| GET | /api/instances/{instanceId}/hmac | instanceId | Get HMAC status |
| POST | /api/instances/{instanceId}/hmac | instanceId | Trigger HMAC rotation |

**Input column includes:**

- Path parameters (required)
- Query parameters (with `?` suffix if optional)
- Body fields (for POST/PATCH)

---

## 12. Unified Engine Tables API Pattern

All engines use unified DLQ and History tables per RFC-72. Engines MUST NOT define per-engine DLQ or history endpoints.

### 12.1 DLQ Endpoints

| Method | Path | Input | Purpose |
| --- | --- | --- | --- |
| GET | /api/dlq | engine?, status?, instanceId?, fromDate?, toDate?, limit?, continuationToken? | List DLQ messages |
| GET | /api/dlq/{engine}/{rowKey} | engine, rowKey | Get message details |
| PATCH | /api/dlq/{engine}/{rowKey} | engine, rowKey, status, resolutionNotes | Update message status |
| POST | /api/dlq/{engine}/{rowKey}/retry | engine, rowKey | Re-enqueue to original queue |
| POST | /api/dlq/expire | olderThanDays, engine? | Bulk expire old messages |

### 12.2 History Endpoints

| Method | Path | Input | Purpose |
| --- | --- | --- | --- |
| GET | /api/history | engine?, instanceId?, status?, operation?, fromDate?, toDate?, correlationId?, limit?, continuationToken? | List history entries |
| GET | /api/history/{engine}/{rowKey} | engine, rowKey | Get entry details |

### 12.3 Engine Values

**Publisher:** `provisioning`, `hmac`, `tls`, `spn`, `update-publisher`, `alerts`

**Managed App:** `update`, `health`, `alerts`

---

# Impact

- All APIs must conform to this standard

---

# Open Questions

None.