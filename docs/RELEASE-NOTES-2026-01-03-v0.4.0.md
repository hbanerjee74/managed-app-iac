# Release Notes — 2026-01-03 (v0.4.0)

## Overview
- Aligns all parameters to RFC-64 names (resourceGroup, sku, computeTier, retentionDays, etc.) - **Breaking change: parameter names changed**
- Adds WAF policy resource for Application Gateway allow/deny rules - **New capability**
- Tags include contactEmail parameter - **New parameter**
- Identity wiring now passes LAW scope for contributor RBAC - **Functional change**

## Highlights
- Gateway uses `ApplicationGatewayWebApplicationFirewallPolicies` instead of inline custom rules - **New capability**
- Parameters: added display/defaulted values (appGwSku, appGwCapacity, storageGB, backupRetentionDays) and contactEmail - **New parameters**

## Upgrade Notes
- **Breaking change**: Update any callers/CI that referenced old param names (`appServicePlanSku`, `postgresComputeTier`, `lawRetentionDays`, `resourceGroupName`) to the RFC-64 equivalents.
