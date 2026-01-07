# Test Harness

This directory contains the test harness for validating Bicep modules and deployments.

## Structure

```
tests/
  unit/                    # Unit tests for individual modules
    fixtures/              # Test wrapper templates and parameters
    helpers/               # Test utility functions
    test_*.py             # Python test files
  e2e/                     # End-to-end tests for main.bicep
    fixtures/              # Full deployment parameters
    test_main.py          # Full-scope test cases
  fixtures/                # Shared test fixtures
    params.dev.json       # Dev/test parameters
```

## Quick Start

### Unit Tests (Module-level)

```bash
# Run all unit tests
pytest tests/unit/

# Run tests for a specific module
pytest tests/unit/test_data.py -v

# Run compilation tests only (no Azure CLI needed)
pytest tests/unit/ -k "compile"
```

### End-to-End Tests (Full-scope)

**For what-if tests (default mode):**
```bash
# 1. Create resource group first (required)
az group create --name <rg-name> --location eastus

# 2. Update tests/fixtures/params.dev.json with your RG name:
#    Set metadata.resourceGroupName to your RG name

# 3. Run what-if tests (safe, no actual deployment)
pytest tests/e2e/
```

**For actual deployment tests (opt-in):**
```bash
# Resource group is created/deleted automatically - no manual setup needed
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

## Test Modes

### Unit Tests
- **Mode**: What-if only
- **Purpose**: Validate individual modules in isolation
- **Dependencies**: Mocked
- **Resources**: None created

### E2E Tests
- **What-if mode** (default): Validates deployment plan
  - **Resource Group**: Must be created manually before running tests
  - Uses resource group name from `tests/fixtures/params.dev.json` → `metadata.resourceGroupName`
  - Test does NOT create or delete the resource group
- **Actual deployment mode** (opt-in): Creates real resources
  - Set `ENABLE_ACTUAL_DEPLOYMENT=true` to enable
  - **Resource Group**: Automatically created before each test and deleted after
  - **WARNING**: Creates real Azure resources!

## Adding New Module Tests

1. Create test wrapper: `tests/unit/fixtures/test-<module>.bicep`
2. Create parameters: `tests/unit/fixtures/params-<module>.json`
3. Create test file: `tests/unit/test_<module>.py`
4. Mock all dependencies in the test wrapper
5. Add test cases for compilation and what-if

See `tests/unit/README.md` for detailed instructions.

## Requirements

- Python 3.x
- pytest
- Azure CLI (`az`)
- Bicep CLI (via Azure CLI)

## Resource Group Management

### What-If Tests (Default Mode)
- **Manual creation required**: You must create the resource group before running tests
- **No automatic cleanup**: The test uses the existing resource group and does not delete it
- **Resource group name**: Configured in `tests/fixtures/params.dev.json` → `metadata.resourceGroupName`

Example:
```bash
# Create resource group
az group create --name test-rg-managed-app --location eastus

# Update params.dev.json metadata.resourceGroupName to "test-rg-managed-app"

# Run tests
pytest tests/e2e/
```

### Actual Deployment Tests (Opt-In)
- **Automatic creation**: Resource group is created before each test
- **Automatic cleanup**: Resource group is deleted after each test (even on failure)
- **Scope**: One resource group per test function
- **Timeout protection**: 5 min creation, 10 min deletion timeouts

When `ENABLE_ACTUAL_DEPLOYMENT=true`:
- Test fixture automatically creates/deletes resource group
- No manual setup required
- Cleanup guaranteed even if tests fail

## CI/CD Integration

Tests are designed to run in CI/CD pipelines:
- Unit tests: Fast, no Azure credentials needed for compilation tests
- E2E what-if: Requires Azure CLI login and pre-existing resource group
- E2E actual deployment: Opt-in only, requires explicit configuration, automatic RG management

