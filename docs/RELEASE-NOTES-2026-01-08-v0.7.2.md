# Release Notes — v0.7.2 (2026-01-08)

## RBAC Refactoring: PowerShell Scripts and Automation Runbooks

This release refactors RBAC role assignments from Bicep resources to PowerShell scripts executed via Azure DeploymentScripts and Automation runbooks. This change improves maintainability, enables on-demand RBAC updates, and clarifies the distinction between Customer Admin and Publisher Admin roles.

### Changes

#### RBAC Module Refactoring (`iac/modules/rbac.bicep`)

##### PowerShell Scripts for RBAC Assignments
- **New scripts**: Three dedicated PowerShell scripts replace explicit Bicep role assignment resources:
  - `scripts/assign-rbac-roles-uami.ps1`: Assigns all RBAC roles for User-Assigned Managed Identity (UAMI)
  - `scripts/assign-rbac-roles-admin.ps1`: Assigns all RBAC roles for Customer Admin
  - `scripts/assign-rbac-roles-publisher-admin.ps1`: Assigns all RBAC roles for Publisher Admin (managed applications only)
- **Execution**: Scripts are executed during deployment via `Microsoft.Resources/deploymentScripts` resources
- **Idempotency**: Scripts use deterministic GUID generation (matching Bicep's `guid()` function) to ensure idempotent role assignments
- **Error handling**: Comprehensive error handling and logging throughout all scripts

##### Automation Runbooks
- **New runbooks**: Three automation runbooks created for on-demand RBAC updates:
  - `assign-rbac-roles-uami`: Re-apply UAMI RBAC assignments
  - `assign-rbac-roles-admin`: Re-apply Customer Admin RBAC assignments
  - `assign-rbac-roles-publisher-admin`: Re-apply Publisher Admin RBAC assignments (managed apps only)
- **State**: Runbooks are created in draft state and must be published before execution
- **Publishing**: Runbooks can be published via Azure Portal or Azure CLI:
  ```bash
  az automation runbook publish \
    --automation-account-name <automation-name> \
    --resource-group <resource-group> \
    --name <runbook-name>
  ```
- **Execution**: Runbooks can be executed on-demand via Azure Portal or Azure CLI:
  ```bash
  az automation runbook start \
    --automation-account-name <automation-name> \
    --resource-group <resource-group> \
    --name <runbook-name>
  ```

##### Parameter Naming Updates
- **Renamed parameters**: All `admin*` parameters renamed to `customerAdmin*` for clarity:
  - `adminObjectId` → `customerAdminObjectId`
  - `adminPrincipalType` → `customerAdminPrincipalType`
- **New parameters**: Added Publisher Admin parameters for managed applications:
  - `publisherAdminObjectId`: Publisher admin Entra object ID
  - `publisherAdminPrincipalType`: Principal type (User or Group, defaults to User)
- **Consistency**: Updated all references across Bicep modules, PowerShell scripts, test fixtures, and parameter validation

##### Deployment Scripts
- **Three deployment scripts**: Created separate `deploymentScripts` resources for each RBAC assignment type:
  - `assignRbacRolesUami`: Executes UAMI script during deployment
  - `assignRbacRolesCustomerAdmin`: Executes Customer Admin script (conditional on `customerAdminObjectId`)
  - `assignRbacRolesPublisherAdmin`: Executes Publisher Admin script (conditional on `isManagedApplication` and `publisherAdminObjectId`)
- **Identity**: All deployment scripts use UAMI for authentication
- **AzPowerShell version**: Updated to version `11.0` (from `10.4`) for better compatibility

#### PowerShell Script Details

##### UAMI RBAC Script (`scripts/assign-rbac-roles-uami.ps1`)
- **Roles assigned**:
  - Resource Group Contributor (RG scope)
  - Key Vault Secrets Officer (KV scope)
  - Storage Blob Data Contributor (Storage scope)
  - ACR Pull (ACR scope)
  - ACR Push (ACR scope)
  - Search Service Contributor (Search scope)
  - Cognitive Services User (AI scope)
  - Automation Job Operator (Automation scope)
- **Managed application support**: Uses `delegatedManagedIdentityResourceId` when `IsManagedApplication` is true
- **Parameters**: Resource IDs passed via environment variables from Bicep

##### Customer Admin RBAC Script (`scripts/assign-rbac-roles-admin.ps1`)
- **Roles assigned**:
  - Resource Group Reader (RG scope)
  - Key Vault Secrets User (KV scope)
  - Storage Blob Data Reader (Storage scope)
  - Storage Queue Data Reader (Storage scope)
  - Storage Table Data Reader (Storage scope)
  - ACR Pull (ACR scope)
  - Search Service Reader (Search scope)
  - Cognitive Services User (AI scope)
- **Principal type**: Supports both User and Group principal types
- **Parameters**: Customer Admin Object ID and Principal Type passed via environment variables

##### Publisher Admin RBAC Script (`scripts/assign-rbac-roles-publisher-admin.ps1`)
- **Roles assigned**: Same as Customer Admin (read-only access)
- **Scope**: Only created for managed applications (`isManagedApplication` = true)
- **Purpose**: Enables publisher admin to troubleshoot and monitor customer resources
- **Parameters**: Publisher Admin Object ID and Principal Type passed via environment variables

#### Test Infrastructure Updates
- **Parameter validation**: Updated `tests/test_params.py` to validate `customerAdminObjectId` and `customerAdminPrincipalType`
- **Test fixtures**: Updated all test fixture Bicep files to use new parameter names:
  - `tests/unit/fixtures/test-rbac.bicep`
  - `tests/unit/fixtures/test-psql-roles.bicep`
  - `tests/unit/fixtures/test-automation.bicep`
  - `tests/unit/fixtures/test-identity.bicep`
- **Test utilities**: Updated `tests/unit/helpers/test_utils.py` to handle `customerAdminObjectId` placeholder replacement
- **Parameter file**: Updated `tests/fixtures/params.dev.json` with new parameter names and Publisher Admin parameters

#### Documentation Updates
- **README.md**: Added comprehensive "Updating RBAC After Deployment" section with:
  - Runbook publishing instructions
  - Runbook execution commands
  - Parameter documentation for each runbook
  - Troubleshooting guidance

### Verification

- ✅ All Bicep modules compile successfully (no errors)
- ✅ All PowerShell scripts validated for syntax and logic
- ✅ All test fixtures updated and compile successfully
- ✅ Parameter validation tests pass
- ✅ Deterministic GUID generation verified for idempotency
- ✅ Deployment scripts configured with correct identity and parameters
- ✅ Automation runbooks created with proper descriptions and dependencies

### Impact

#### Improved Maintainability
- **Centralized logic**: RBAC assignment logic consolidated in PowerShell scripts
- **Easier updates**: Role assignments can be updated by modifying scripts without Bicep changes
- **Better testing**: Scripts can be tested independently of Bicep deployment

#### Operational Benefits
- **On-demand updates**: RBAC assignments can be re-applied via automation runbooks without full redeployment
- **Troubleshooting**: Runbooks enable quick RBAC fixes if assignments are accidentally removed
- **Audit trail**: Runbook execution logged in Automation Account job history

#### Clarity Improvements
- **Naming consistency**: `customerAdmin*` naming clearly distinguishes Customer Admin from Publisher Admin
- **Documentation**: Comprehensive runbook documentation in README
- **Parameter clarity**: Explicit parameter names reduce confusion about admin roles

### Related Issues

- RBAC role assignments refactored to PowerShell scripts
- Automation runbooks for on-demand RBAC updates
- Customer Admin vs Publisher Admin role clarity
- Parameter naming consistency (`admin*` → `customerAdmin*`)
- Managed application Publisher Admin support

### Migration Notes

**No migration required.** This release refactors internal implementation without changing functionality:

- Existing RBAC assignments remain unchanged
- Role assignments still occur during deployment
- New runbooks are created but optional (can be published and executed as needed)
- Parameter names changed but values remain the same (update `params.dev.json` if using old names)

**For developers:**
- Update `params.dev.json`: Rename `adminObjectId` → `customerAdminObjectId` and `adminPrincipalType` → `customerAdminPrincipalType`
- Add Publisher Admin parameters if deploying managed applications:
  ```json
  "publisherAdminObjectId": { "value": "<publisher-admin-object-id>" },
  "publisherAdminPrincipalType": { "value": "User" }
  ```
- Test fixtures: All test fixtures updated to use new parameter names
- PowerShell scripts: Located in `scripts/` directory, can be executed independently for testing

**For operators:**
- **Publishing runbooks**: After deployment, publish runbooks via Azure Portal or CLI:
  ```bash
  az automation runbook publish \
    --automation-account-name <automation-name> \
    --resource-group <resource-group> \
    --name assign-rbac-roles-uami
  ```
- **Executing runbooks**: Runbooks can be executed on-demand to re-apply RBAC assignments:
  ```bash
  az automation runbook start \
    --automation-account-name <automation-name> \
    --resource-group <resource-group> \
    --name assign-rbac-roles-admin
  ```
- **RBAC updates**: If RBAC assignments are removed or need updating, execute the appropriate runbook instead of redeploying

### Files Changed

**Created:**
- `scripts/assign-rbac-roles-uami.ps1`
- `scripts/assign-rbac-roles-admin.ps1`
- `scripts/assign-rbac-roles-publisher-admin.ps1`

**Modified:**
- `iac/modules/rbac.bicep` (refactored to use PowerShell scripts and automation runbooks)
- `iac/main.bicep` (updated parameter names: `adminObjectId` → `customerAdminObjectId`, `adminPrincipalType` → `customerAdminPrincipalType`; added Publisher Admin parameters)
- `tests/fixtures/params.dev.json` (renamed admin parameters, added Publisher Admin parameters)
- `tests/test_params.py` (updated required parameter validation)
- `tests/unit/helpers/test_utils.py` (updated placeholder replacement logic)
- `tests/unit/fixtures/test-rbac.bicep` (updated parameter names)
- `tests/unit/fixtures/test-psql-roles.bicep` (updated parameter names)
- `tests/unit/fixtures/test-automation.bicep` (updated parameter names)
- `tests/unit/fixtures/test-identity.bicep` (updated parameter names)
- `README.md` (added "Updating RBAC After Deployment" section)
- `AGENTS.md` (updated parameter references)

**Removed:**
- All explicit `Microsoft.Authorization/roleAssignments` resources from `rbac.bicep` (replaced with PowerShell script execution)
