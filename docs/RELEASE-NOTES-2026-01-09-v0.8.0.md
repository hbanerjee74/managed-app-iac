# Release Notes — v0.8.0 (2026-01-09)

## Single-Tenant Deployment Simplification

This release simplifies the infrastructure for single-tenant deployment by removing all managed application (cross-tenant) functionality, including `isManagedApplication` parameter, publisher admin support, and publisher IP ranges. The codebase is now streamlined for single-tenant deployments while maintaining UAMI for service identity and PostgreSQL managed identity authentication.

### Changes

#### Removed Managed Application Support

##### Removed `isManagedApplication` Parameter
- **Removed from `iac/main.bicep`**: Eliminated `isManagedApplication` parameter and all conditional logic based on it
- **Removed from `iac/modules/rbac.bicep`**: Removed `isManagedApplication` parameter and publisher admin runbook creation
- **Removed from test files**: Updated `tests/fixtures/params.dev.json`, `tests/test_params.py`, and test fixtures
- **Removed from test utilities**: Updated `tests/unit/helpers/test_utils.py` to remove `isManagedApplication` handling logic
- **Impact**: Codebase now assumes single-tenant deployment; deployer identity is always used for customer admin

##### Removed Publisher Admin Support
- **Removed publisher admin parameters**: Eliminated `publisherAdminObjectId` and `publisherAdminPrincipalType` from `iac/main.bicep` and `iac/modules/rbac.bicep`
- **Removed publisher admin runbook**: Deleted `scripts/assign-rbac-roles-publisher-admin.ps1` script
- **Removed publisher admin runbook resource**: Removed `rbacPublisherAdminRunbook` resource from `iac/modules/rbac.bicep`
- **Updated documentation**: Removed all publisher admin references from `README.md` and `AGENTS.md`
- **Impact**: Only customer admin (deployer identity) and UAMI runbooks remain

##### Removed Publisher IP Ranges
- **Removed `publisherIpRanges` parameter**: Eliminated from `iac/main.bicep` and `iac/modules/waf-policy.bicep`
- **Removed publisher WAF allow rule**: Removed "Allow-Publisher" rule from WAF policy
- **Kept customer IP ranges**: `customerIpRanges` parameter remains for customer IP allowlist
- **WAF policy simplified**: Now only has customer allow rule (priority 1) and deny-all rule (priority 2)
- **Impact**: WAF policy only allows customer IP ranges; all other traffic is denied

##### Removed Delegated Managed Identity Support
- **Removed `delegatedManagedIdentityResourceId`**: All role assignments now created directly without delegated managed identity
- **Updated PowerShell scripts**: Removed `DelegatedManagedIdentityResourceId` parameter from `scripts/assign-rbac-roles-uami.ps1`
- **Updated documentation**: Updated `AGENTS.md` to reflect single-tenant deployment model
- **Impact**: Role assignments are simpler and work directly in single-tenant scenarios

#### Simplified RBAC Architecture

##### Deployer Identity for Customer Admin
- **Always uses deployer identity**: `effectiveCustomerAdminObjectId` now always uses `deployerInfo.objectId` from `az.deployer()`
- **Removed conditional logic**: No more conditional assignment based on `isManagedApplication`
- **Automation Job Operator**: Deployer identity automatically gets Automation Job Operator role on Automation Account
- **Impact**: Simpler, more predictable RBAC assignments

##### Moved Deployer Automation Job Operator Role Assignment
- **Moved to automation module**: Role assignment moved from `iac/main.bicep` to `iac/modules/automation.bicep` to properly scope to automation account resource
- **Added parameters**: `automation.bicep` now accepts `deployerObjectId` and `deployerPrincipalType` parameters
- **Impact**: Better resource scoping and cleaner module organization

#### Documentation Updates

##### Updated README.md
- **Removed `isManagedApplication` section**: Eliminated entire section explaining managed application parameter
- **Removed publisher admin references**: Updated runbooks section from 3 to 2 runbooks
- **Removed publisher IP ranges**: Updated network parameters section
- **Updated runbook documentation**: Removed publisher admin runbook publishing/execution instructions
- **Updated runbook parameters**: Removed `IsManagedApplication` and publisher admin parameters from documentation

##### Updated AGENTS.md
- **Updated RBAC section**: Changed from "Managed Application Requirements" to "Single-Tenant Deployment"
- **Removed delegated managed identity**: Updated to reflect direct role assignments
- **Updated WAF description**: Changed from "customer/publisher IP allowlists" to "customer IP allowlist"
- **Removed publisher admin script**: Updated scripts list

### Verification

- ✅ All Bicep files compile successfully
- ✅ No remaining references to `isManagedApplication` in active code
- ✅ No remaining references to `publisherAdmin` in active code
- ✅ No remaining references to `publisherIpRanges` in active code
- ✅ No remaining references to `delegatedManagedIdentityResourceId` in active code
- ✅ All test fixtures updated
- ✅ Documentation updated

### Impact

#### Simplified Deployment Model
- **Single-tenant focus**: Codebase now optimized for single-tenant deployments
- **Reduced complexity**: Removed ~400 lines of conditional logic and managed application code
- **Clearer intent**: Code clearly shows single-tenant deployment pattern

#### Operational Benefits
- **Simpler RBAC**: Direct role assignments without delegated managed identity complexity
- **Easier troubleshooting**: No conditional logic to debug
- **Reduced parameters**: Fewer parameters to manage and configure

#### Maintainability
- **Less code to maintain**: Removed publisher admin script and related infrastructure
- **Clearer codebase**: No conditional logic based on deployment type
- **Better documentation**: Documentation reflects actual single-tenant deployment model

### Related Issues

- Single-tenant deployment simplification
- Removal of managed application (cross-tenant) support
- WAF policy simplification (customer IP ranges only)

### Migration Notes

**Breaking changes:** This release includes breaking changes for managed application deployments:

- **`isManagedApplication` parameter removed**: This parameter no longer exists. Codebase assumes single-tenant deployment.
- **Publisher admin support removed**: `publisherAdminObjectId` and `publisherAdminPrincipalType` parameters removed. Publisher admin runbook no longer created.
- **Publisher IP ranges removed**: `publisherIpRanges` parameter removed. WAF policy only supports customer IP ranges.
- **Delegated managed identity removed**: All role assignments now created directly without `delegatedManagedIdentityResourceId`.

**For developers:**
- **Update `params.dev.json`**: Remove `isManagedApplication`, `publisherAdminObjectId`, `publisherAdminPrincipalType`, and `publisherIpRanges` from parameters
- **Update test fixtures**: Remove managed application related parameters from test fixtures
- **Simplified RBAC**: Deployer identity is automatically used for customer admin

**For operators:**
- **Single-tenant only**: Infrastructure now supports single-tenant deployments only
- **Customer IP ranges only**: WAF policy only allows customer IP ranges (no publisher IP ranges)
- **Simpler RBAC**: Role assignments are direct (no delegated managed identity)

### Files Changed

**Deleted:**
- `scripts/assign-rbac-roles-publisher-admin.ps1` (publisher admin script removed)

**Modified:**
- `iac/main.bicep` (removed `isManagedApplication`, `publisherAdminObjectId`, `publisherAdminPrincipalType`, `publisherIpRanges`; simplified customer admin logic)
- `iac/modules/automation.bicep` (added deployer Automation Job Operator role assignment)
- `iac/modules/rbac.bicep` (removed `isManagedApplication`, publisher admin parameters and runbook)
- `iac/modules/waf-policy.bicep` (removed `publisherIpRanges` parameter and publisher allow rule)
- `scripts/assign-rbac-roles-uami.ps1` (removed `IsManagedApplication` and `DelegatedManagedIdentityResourceId` parameters)
- `tests/fixtures/params.dev.json` (removed managed application parameters)
- `tests/test_params.py` (removed `publisherIpRanges` from required parameters)
- `tests/unit/fixtures/test-rbac.bicep` (removed managed application parameters)
- `tests/unit/fixtures/test-waf-policy.bicep` (removed `publisherIpRanges`)
- `tests/unit/fixtures/test-gateway.bicep` (removed `publisherIpRanges`)
- `tests/unit/helpers/test_utils.py` (removed `isManagedApplication` handling)
- `README.md` (removed managed application documentation)
- `AGENTS.md` (updated for single-tenant deployment)
