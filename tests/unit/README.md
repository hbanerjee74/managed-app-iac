# Unit Tests for Bicep Modules

This directory contains parameterized unit tests for all Bicep modules.

## Structure

```
tests/unit/
  fixtures/
    test-<module>.bicep      # Test wrapper templates
    params-<module>.json     # Module-specific test parameters
  helpers/
    test_utils.py            # Common test utilities
    what_if_parser.py        # What-if output parser utilities
  test_modules.py           # Single parameterized test file for all modules
```

## Running Tests

```bash
# Run all unit tests (all modules)
pytest tests/unit/test_modules.py -v

# Run tests for a specific module
pytest tests/unit/test_modules.py -v -k "diagnostics"
pytest tests/unit/test_modules.py -v -k "network"

# Run only compilation tests (no Azure CLI needed)
pytest tests/unit/test_modules.py -v -k "compiles"

# Run only what-if tests
pytest tests/unit/test_modules.py -v -k "what_if"
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
3. Add the module to the `MODULES` list in `test_modules.py`:
   ```python
   MODULES = [
       ...
       ('newmodule', 'test-newmodule.bicep', 'params-newmodule.json'),
   ]
   ```
4. Mock all dependencies in the test wrapper
5. All standard tests (compilation, parameter validation, what-if) will run automatically