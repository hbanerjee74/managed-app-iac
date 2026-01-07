# Unit Tests for Bicep Modules

This directory contains unit tests for individual Bicep modules.

## Structure

```
tests/unit/
  fixtures/
    test-<module>.bicep      # Test wrapper templates
    params-<module>.json     # Module-specific test parameters
  helpers/
    test_utils.py            # Common test utilities
  test_<module>.py          # Python test files
```

## Running Tests

```bash
# Run all unit tests
pytest tests/unit/

# Run tests for a specific module
pytest tests/unit/test_data.py

# Run with verbose output
pytest tests/unit/ -v
```

## Test Wrapper Templates

Each module has a test wrapper template (`test-<module>.bicep`) that:
- Includes the `naming.bicep` module
- Mocks all required dependencies
- Calls the module under test with test parameters
- Exposes outputs for validation

## What-If Mode

All unit tests use **what-if mode only** - no actual Azure resources are created. This means:
- Tests run fast
- No Azure credentials required (for compilation tests)
- Safe to run in CI/CD
- What-if tests require Azure CLI login (but no actual deployment)

## Adding New Module Tests

1. Create `test-<module>.bicep` in `fixtures/`
2. Create `params-<module>.json` in `fixtures/`
3. Create `test_<module>.py` in `tests/unit/`
4. Mock all dependencies in the test wrapper
5. Add test cases for compilation, parameter validation, and what-if

