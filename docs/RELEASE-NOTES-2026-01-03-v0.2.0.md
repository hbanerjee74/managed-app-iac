# Release Notes — 2026-01-03 (v0.2.0)

## Overview
- New RG-scope entrypoint (`iac/main.rg.bicep`) for dev/test deployments - **New capability**
- Adds an extra delegated `/28` `snet-psql` subnet for PostgreSQL Flexible Server - **New subnet added**
- RG guardrail: deployment scripts require the target RG to be tagged `IAC=true` - **New requirement**

## Highlights
- New RG-scope entrypoint for dev/test deployments using the same RFC-64 parameters
- Adds dedicated PostgreSQL subnet (`snet-psql`) for PostgreSQL Flexible Server private access
- Deployment scripts require target RG to be tagged `IAC=true` for safety

## Notes
- Strict enforcement uses Complete mode at RG scope; ensure the RG contains only managed resources to avoid accidental deletions.
