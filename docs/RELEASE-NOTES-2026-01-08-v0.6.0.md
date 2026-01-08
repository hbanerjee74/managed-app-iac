# Release Notes — v0.6.0 (2026-01-08)

## Test Harness Improvements and Documentation Consolidation

Major improvements to the test harness documentation, test output, and E2E test functionality.

### Changes

#### Test Documentation Consolidation
- **Merged `tests/e2e/README.md` into `tests/README.md`**: Consolidated all test documentation into a single comprehensive guide
- **Removed duplication**: Main `README.md` now provides high-level overview and references `tests/README.md` for details
- **Improved structure**: Clear separation between Quick Start and detailed sections

#### Enhanced Test Output
- **Added `pytest.ini`**: Default verbose output configuration for better test visibility
  - Shows test names by default (`-v`)
  - Shows all test outcomes (`-ra`)
  - Shorter tracebacks (`--tb=short`)
- **Documented verbose options**: Added comprehensive guide for test output flags (`-v`, `-vv`, `-rs`, `-ra`)

#### E2E Test Improvements
- **Fixed `test_post_deployment_state_check`**: Merged into `test_actual_deployment` to work correctly with function-scoped fixtures
  - Post-deployment validation now runs before resource group cleanup
  - Single test performs deployment + state validation
- **Added `KEEP_RESOURCE_GROUP` option**: New environment variable to skip resource group cleanup for debugging
  - Set `KEEP_RESOURCE_GROUP=true` to keep resources after tests
  - Useful for inspecting deployed resources and debugging
  - Documented in both Quick Start and detailed sections

#### Documentation Enhancements
- **Added troubleshooting section**: Common issues and solutions documented
- **Enhanced CI/CD section**: Service principal authentication examples added
- **Improved resource group management docs**: Clear explanation of automatic vs manual RG management
- **Added test types explanation**: Detailed breakdown of what each test validates

### Verification

- ✅ All test scenarios documented in `tests/README.md`
- ✅ No duplication between `README.md` and `tests/README.md`
- ✅ `KEEP_RESOURCE_GROUP` option works correctly
- ✅ `test_actual_deployment` performs both deployment and validation
- ✅ Pytest verbose output shows test names and skip reasons

### Impact

- **Better developer experience**: Clear, consolidated test documentation
- **Improved debugging**: `KEEP_RESOURCE_GROUP` option allows resource inspection
- **Better test visibility**: Verbose output by default shows which tests pass/fail/skip
- **Fixed test reliability**: Post-deployment validation now works correctly
- **Reduced confusion**: Single source of truth for test documentation

### Related Issues

- Test documentation consolidation
- E2E test post-deployment validation fix
- Test output visibility improvements

### Migration Notes

No migration required. All changes are backward compatible:

- Existing test commands continue to work
- New `KEEP_RESOURCE_GROUP` option is opt-in (defaults to cleanup)
- `pytest.ini` improves output but doesn't change test behavior
- Test documentation consolidation doesn't affect test execution

### Documentation Links

- **Test Documentation**: See [`tests/README.md`](../tests/README.md) for comprehensive test guide
- **Main README**: See [`README.md`](../README.md) for project overview

