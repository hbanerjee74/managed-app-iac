# Release Notes — v0.7.0 (2026-01-08)

## Module Refactoring: Split Security Module into Focused Modules

Major refactoring to improve maintainability and separation of concerns by splitting the monolithic `security.bicep` module into three focused modules: `kv.bicep`, `storage.bicep`, and `acr.bicep`.

### Changes

#### Module Refactoring
- **Split `security.bicep` into three modules**:
  - `iac/modules/kv.bicep`: Key Vault resources (vault, private endpoint, DNS, RBAC, diagnostics)
  - `iac/modules/storage.bicep`: Storage Account resources (account, blob container, queues, tables, private endpoints, DNS, RBAC, diagnostics)
  - `iac/modules/acr.bicep`: Container Registry resources (registry, private endpoint, DNS, RBAC, diagnostics)
- **Updated `iac/main.bicep`**: Replaced single `security` module call with three separate module calls (`kv`, `storage`, `acr`)
- **Maintained backward compatibility**: All modules maintain the same outputs (`kvId`, `storageId`, `acrId`) for potential future use

#### Test Infrastructure Updates
- **Created new unit test fixtures**:
  - `tests/unit/fixtures/test-kv.bicep` + `params-kv.json`
  - `tests/unit/fixtures/test-storage.bicep` + `params-storage.json`
  - `tests/unit/fixtures/test-acr.bicep` + `params-acr.json`
- **Updated `tests/unit/test_modules.py`**: Replaced `security` module entry with three new module entries (`kv`, `storage`, `acr`)
- **Removed obsolete test files**:
  - `tests/unit/fixtures/test-security.bicep`
  - `tests/unit/fixtures/params-security.json`

#### Code Quality
- **Improved maintainability**: Each module now has a single, focused responsibility
- **Better separation of concerns**: Key Vault, Storage, and Container Registry resources are now independently testable and deployable
- **Consistent structure**: All three modules follow the same pattern (resource, private endpoints, DNS, RBAC, diagnostics)

### Verification

- ✅ All three new modules compile successfully (no linter errors)
- ✅ `main.bicep` updated to use new modules
- ✅ Unit test fixtures created and integrated into test suite
- ✅ Parameter file tests pass for all three modules
- ✅ Old `security.bicep` module and test files removed

### Impact

- **Better code organization**: Each module focuses on a single Azure service
- **Improved testability**: Modules can be tested independently
- **Easier maintenance**: Changes to one service don't affect others
- **Clearer dependencies**: Module dependencies are more explicit
- **No functional changes**: All resources deploy identically, just organized differently

### Related Issues

- Module refactoring for better maintainability
- Separation of concerns for Key Vault, Storage, and Container Registry

### Migration Notes

**No migration required.** This is a pure refactoring with no functional changes:

- All resources deploy identically to previous versions
- Parameter structure unchanged
- Outputs maintained for backward compatibility
- Test commands remain the same (`pytest tests/unit/test_modules.py -v`)

**For developers:**
- If you have local references to `security.bicep`, update them to use `kv.bicep`, `storage.bicep`, or `acr.bicep` as appropriate
- Unit tests now test three modules instead of one (`kv`, `storage`, `acr` instead of `security`)
- Module outputs (`kvId`, `storageId`, `acrId`) remain available but are currently unused

### Files Changed

**Created:**
- `iac/modules/kv.bicep`
- `iac/modules/storage.bicep`
- `iac/modules/acr.bicep`
- `tests/unit/fixtures/test-kv.bicep`
- `tests/unit/fixtures/params-kv.json`
- `tests/unit/fixtures/test-storage.bicep`
- `tests/unit/fixtures/params-storage.json`
- `tests/unit/fixtures/test-acr.bicep`
- `tests/unit/fixtures/params-acr.json`

**Modified:**
- `iac/main.bicep` (replaced `security` module with `kv`, `storage`, `acr` modules)
- `tests/unit/test_modules.py` (updated MODULES list)

**Deleted:**
- `iac/modules/security.bicep`
- `iac/modules/security.json` (compiled output)
- `tests/unit/fixtures/test-security.bicep`
- `tests/unit/fixtures/params-security.json`

