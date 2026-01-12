# Release Notes — v0.7.3 (2026-01-08)

## Parameter Centralization and Credential Management Refactoring

This release centralizes parameter management by removing all hardcoded defaults from modules, introduces a dedicated secrets module for credential management, and makes RBAC parameters mandatory. These changes improve maintainability, ensure consistent parameter handling, and clarify deployment requirements.

### Changes

#### Parameter Centralization

##### Removed Hardcoded Defaults from All Modules
- **All module parameters are now mandatory**: Previously, modules had hardcoded default values for various parameters (e.g., `tags`, `vmSize`, `storageGB`, `backupRetentionDays`, `appGwCapacity`, `appGwSku`, `aiServicesTier`, `retentionDays`). These defaults have been removed, requiring all parameters to be explicitly provided from `main.bicep` (which gets them from `params.dev.json`).
- **Modules affected**: All 15+ modules updated to remove default values:
  - `vm-jumphost.bicep`: Removed defaults for `vmSize`, `tags`, VM image parameters (`imagePublisher`, `imageOffer`, `imageSku`, `imageVersion`)
  - `psql.bicep`: Removed defaults for `storageGB`, `backupRetentionDays`, `tags`
  - `gateway.bicep`: Removed defaults for `appGwCapacity`, `appGwSku`, `tags`
  - `rbac.bicep`: Removed defaults for `customerAdminPrincipalType`, `lawId`, `lawName`, `kvId`, `storageId`, `acrId`, `searchId`, `aiId`, `automationName`, `isManagedApplication`, `publisherAdminObjectId`, `publisherAdminPrincipalType`, `tags`
  - `psql-roles.bicep`: Removed defaults for `automationId`, `automationName`, `tags`
  - All other modules: Removed `tags` default values
- **Impact**: All parameters must now be explicitly provided in `params.dev.json` or `main.bicep`

##### New Secrets Module (`iac/modules/secrets.bicep`)
- **Centralized credential management**: New dedicated module for creating Key Vault secrets for admin credentials
- **Secrets created**:
  - `vm-admin-username`: VM admin username
  - `vm-admin-password`: VM admin password
  - `psql-admin-username`: PostgreSQL admin username
  - `psql-admin-password`: PostgreSQL admin password
- **Outputs**: Module exposes secret names as outputs for use in other modules:
  - `vmAdminUsernameSecretName`
  - `vmAdminPasswordSecretName`
  - `psqlAdminUsernameSecretName`
  - `psqlAdminPasswordSecretName`
- **Benefits**: Centralizes credential management, improves maintainability, and ensures consistent secret naming

##### Credential Generation in `main.bicep`
- **VM admin password**: Auto-generated using `guid()` if not provided in `params.dev.json`
- **PostgreSQL admin password**: Auto-generated using `guid()` if not provided in `params.dev.json`
- **Generation logic**: Uses deterministic GUID generation based on subscription ID, Key Vault ID, and secret purpose
- **Default values**: Usernames default to `azureuser` (VM) and `psqladmin` (PostgreSQL) if not provided

##### Mandatory RBAC Parameters
- **All RBAC parameters are now mandatory**: Previously, some RBAC parameters had conditional checks (`if (!empty(...))`). These conditionals have been removed, making all parameters mandatory.
- **Modules affected**:
  - `rbac.bicep`: All parameters now mandatory (removed conditional checks for `customerAdminObjectId`, `publisherAdminObjectId`, `automationId`, `automationName`)
  - `psql-roles.bicep`: All parameters now mandatory (removed conditional checks for `automationId`, `automationName`)
- **Impact**: `main.bicep` must now provide all RBAC-related outputs to these modules


### Verification

- ✅ All modules compile successfully (no linter errors)
- ✅ All test fixtures updated with mandatory parameters
- ✅ All 19 module compilation tests pass
- ✅ Main Bicep template compiles successfully
- ✅ Secrets module creates all required credentials
- ✅ Parameter validation tests pass

### Impact

#### Improved Maintainability
- **Centralized parameter management**: All parameters flow through `main.bicep` → `params.dev.json`, making it easier to track and manage configuration
- **Consistent parameter handling**: No hidden defaults, all parameters explicitly defined

#### Operational Benefits
- **Easier troubleshooting**: All parameters visible in `params.dev.json`, no hidden defaults
- **Consistent credential management**: Centralized secrets module ensures consistent secret naming and management

#### Developer Experience
- **Clearer contracts**: Modules have explicit parameter requirements, no hidden defaults
- **Better testability**: All parameters must be provided in test fixtures, improving test coverage
- **Easier maintenance**: Changes to parameters only need to be made in `main.bicep` and `params.dev.json`

### Related Issues

- Parameter centralization and removal of hardcoded defaults
- Centralized credential management via secrets module
- Mandatory RBAC parameters for clearer contracts

### Migration Notes

**Breaking changes:** This release includes breaking changes for parameter handling:

- **All parameters must be provided**: Previously, modules had defaults that could be omitted. Now all parameters must be explicitly provided in `params.dev.json`.
- **No module-level defaults**: Modules no longer have hardcoded defaults. All defaults must be in `main.bicep` or `params.dev.json`.

**For developers:**
- **Update `params.dev.json`**: Ensure all parameters are explicitly defined (no relying on module defaults)
- **New secrets module**: Credentials are now managed via `secrets.bicep` module (automatically called by `main.bicep`)
- **RBAC parameters**: All RBAC-related parameters are now mandatory (no conditional checks)
- **Test fixtures**: All test fixtures updated to include mandatory parameters

**For operators:**
- **Parameter validation**: All parameters must be provided in parameter files (no module defaults)
- **Credential management**: VM and PostgreSQL admin credentials are auto-generated if not provided, stored in Key Vault via `secrets.bicep` module

### Files Changed

**Created:**
- `iac/modules/secrets.bicep` (new module for centralized credential management)

**Modified:**
- `iac/main.bicep` (credential generation logic, secrets module call, all parameters passed explicitly)
- `iac/modules/vm-jumphost.bicep` (removed defaults)
- `iac/modules/psql.bicep` (removed defaults)
- `iac/modules/gateway.bicep` (removed defaults)
- `iac/modules/rbac.bicep` (removed defaults, made all parameters mandatory)
- `iac/modules/psql-roles.bicep` (removed defaults, made all parameters mandatory)
- All other modules (removed `tags` defaults)
- `tests/fixtures/params.dev.json` (added VM image parameters)
- `tests/unit/fixtures/test-psql.bicep` (added secrets module, mandatory parameters)
- `tests/unit/fixtures/test-vm-jumphost.bicep` (added secrets module, mandatory parameters)
- `tests/unit/fixtures/test-psql-roles.bicep` (added secrets module, mandatory parameters)
- `tests/unit/fixtures/test-rbac.bicep` (added mandatory parameters)
