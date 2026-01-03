# Security Policy

## Supported Versions
| Version | Status      |
|---------|-------------|
| v1.0.x  | Supported   |
| <1.0.0  | Not supported |

## Reporting a Vulnerability
- Email: hello@acceleratedata.ai (PGP optional)
- Include: affected files/modules, steps to reproduce, expected vs. actual behavior, and any logs or outputs (redact secrets).
- Please do **not** open public issues for suspected vulnerabilities.

## Handling Process
1. Acknowledge within 2 business days.
2. Triage and assign severity.
3. Provide a fix/mitigation or planned timeline.
4. Credit reporters if desired.

## Scope for This Repo
- Azure IaC (Bicep modules, scripts, validator tooling) under `iac/`, `scripts/`, `tests/`.
- Not in scope: downstream application code or runtime workloads.

## Secure Development Notes
- Public network access is disabled by default for PaaS resources; validate any changes against RFC-42/64/71.
- Managed identities and RBAC bindings are preferred over keys; avoid adding shared keys or public endpoints.
- Run `pytest` (including validator offline tests) before releasing changes.
