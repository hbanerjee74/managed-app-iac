# Test Harness

This directory contains the test harness for validating Bicep modules and deployments.

## Structure

```
tests/
  unit/                    # Unit tests for individual modules
    fixtures/              # Test wrapper templates and module-specific parameters
    helpers/               # Test utility functions
    test_modules.py        # Parameterized test file for all modules
  e2e/                     # End-to-end tests for main.bicep
    test_main.py          # Full-scope test cases
  fixtures/                # Shared test fixtures
    params.dev.json       # Single source of truth for RG name, location, and all parameters
  e2e/
    state_check/           # What-if drift detection utilities
      what_if.sh          # Run what-if and save JSON output
      diff_report.py      # Summarize what-if changes
    validator/             # Post-deployment validation tools
      collect_actual_state.py  # Collect actual Azure resource state
      compare_expectation.py   # Compare actual vs expected state
      expected/              # Expected state templates
  test_params.py          # Validates params.dev.json has required parameters
  test_shell_scripts.py   # Lints shell scripts with shellcheck
```

## Quick Start

### Prerequisites

1. **Authenticate with Azure CLI:**
   ```bash
   az login
   ```

2. **Configure test parameters:**
   Edit `tests/fixtures/params.dev.json`:
   ```json
   {
     "metadata": {
       "subscriptionId": "your-subscription-id",
       "resourceGroupName": "test-rg-managed-app",
       "location": "eastus"
     },
     "parameters": {
       ...
     }
   }
   ```

### Unit Tests (Module-level)

```bash
# Run all unit tests
pytest tests/unit/test_modules.py -v

# Run tests for a specific module
pytest tests/unit/test_modules.py -v -k "network"

# Run compilation tests only (no Azure CLI needed)
pytest tests/unit/test_modules.py -v -k "compiles"
```

**Note**: Unit tests automatically create the resource group if it doesn't exist (using RG name and location from `tests/fixtures/params.dev.json`).

### End-to-End Tests (Full-scope)

**For what-if tests (default mode):**
```bash
# Resource group must exist (unit tests will create it, or create manually)
az group create --name test-rg-managed-app --location eastus

# Run what-if tests (safe, no actual deployment)
pytest tests/e2e/
```

**For actual deployment tests (opt-in):**
```bash
# Resource group is created/deleted automatically - no manual setup needed
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

## Test Configuration

### Single Source of Truth: `tests/fixtures/params.dev.json`

Both unit tests and E2E tests read `resourceGroupName` and `location` from `tests/fixtures/params.dev.json`:

- **`metadata.resourceGroupName`** - Resource group name for all tests
- **`metadata.location`** - Azure region for all tests
- **`metadata.subscriptionId`** - (Optional) Subscription ID for E2E tests

**Why?** This ensures consistency across all tests and matches the managed application deployment model where ARM provides these values.

### Module-Specific Parameters

Unit tests use module-specific parameter files (`tests/unit/fixtures/params-<module>.json`) for module-specific parameters, but **always** read RG name and location from the shared `params.dev.json`.

## Test Modes

### Unit Tests
- **Mode**: What-if only
- **Purpose**: Validate individual modules in isolation
- **Dependencies**: Mocked in test wrappers
- **Resources**: None created (what-if only)
- **RG Management**: Automatically creates RG if missing (from shared params)

### E2E Tests
- **What-if mode** (default): Validates deployment plan
  - **Resource Group**: Must exist (unit tests create it, or create manually)
  - Uses resource group name from `tests/fixtures/params.dev.json` → `metadata.resourceGroupName`
  - Test does NOT create or delete the resource group
- **Actual deployment mode** (opt-in): Creates real resources
  - Set `ENABLE_ACTUAL_DEPLOYMENT=true` to enable
  - **Resource Group**: Automatically created before each test and deleted after
  - **WARNING**: Creates real Azure resources!

## Test Files Explained

### `test_params.py`
**Purpose**: Validates that `tests/fixtures/params.dev.json` contains all required parameters for `main.bicep`.

**What it checks:**
- All required parameters are present in the `parameters` section
- `metadata.resourceGroupName` and `metadata.location` are present

**Usage:**
```bash
pytest tests/test_params.py
```

### `test_shell_scripts.py`
**Purpose**: Lints shell scripts in `scripts/deploy/` using `shellcheck` (if available).

**What it does:**
- Checks if `shellcheck` is installed
- If available, runs `shellcheck` on all `.sh` files in `scripts/deploy/`
- Silently skips if `shellcheck` is not installed

**Usage:**
```bash
pytest tests/test_shell_scripts.py
```

**Note**: This is a code quality check, not a functional test.

### `e2e/state_check/` Folder
**Purpose**: What-if drift detection utilities for comparing Bicep templates against deployed resource groups.

**Components:**
- **`what_if.sh`**: Runs `az deployment group what-if` and saves JSON output
  - Usage: `./tests/e2e/state_check/what_if.sh [params_file]`
  - Extracts resource group name from params file
  - Outputs to `tests/e2e/state_check/what-if.json`

- **`diff_report.py`**: Summarizes what-if changes
  - Usage: `python tests/e2e/state_check/diff_report.py tests/e2e/state_check/what-if.json`
  - Provides summary counts (Create, Modify, Delete, NoChange)
  - Exits with error code if changes detected

**Usage:**
```bash
# Run what-if and generate summary
./tests/e2e/state_check/what_if.sh tests/fixtures/params.dev.json
python tests/e2e/state_check/diff_report.py tests/e2e/state_check/what-if.json
```

### `e2e/validator/` Folder
**Purpose**: Post-deployment validation tools to compare actual Azure resource state against expected templates.

**Components:**
- **`collect_actual_state.py`**: Collects actual resource state from Azure
  - Usage: `python tests/e2e/validator/collect_actual_state.py <resource-group-name> > /tmp/actual.json`
  - Filters resources by module type
  - Extracts key properties for validation

- **`compare_expectation.py`**: Compares actual state against expected templates
  - Supports pattern matching (e.g., `<16>` for nanoid length, `<guid>` for GUIDs)
  - Validates resource properties match expected values

- **`expected/`**: Expected state templates
  - `dev_expectation.template.json` - Full deployment expectations
  - `modules/*.json` - Module-specific expectations

- **`test_modules.py`**: Pytest tests for module-level validation
  - Requires `ACTUAL_PATH` environment variable
  - Compares actual state against expected templates

**Usage:**
```bash
# 1. Collect actual state
python tests/e2e/validator/collect_actual_state.py test-rg-managed-app > /tmp/actual.json

# 2. Compare against expectations
ACTUAL_PATH=/tmp/actual.json pytest tests/e2e/validator/test_modules.py
```

**Note**: This is for post-deployment validation, not pre-deployment testing.

## Resource Group Management

### Unit Tests
- **Automatic creation**: Resource group is created if it doesn't exist
- **Source**: RG name and location from `tests/fixtures/params.dev.json` → `metadata`
- **No cleanup**: Resource group persists after tests (shared across test runs)

### E2E Tests - What-If Mode (Default)
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

### E2E Tests - Actual Deployment Mode (Opt-In)
- **Automatic creation**: Resource group is created before each test
- **Automatic cleanup**: Resource group is deleted after each test (even on failure)
- **Scope**: One resource group per test function
- **Timeout protection**: 5 min creation, 10 min deletion timeouts

When `ENABLE_ACTUAL_DEPLOYMENT=true`:
- Test fixture automatically creates/deletes resource group
- No manual setup required
- Cleanup guaranteed even if tests fail

## Adding New Module Tests

1. Create test wrapper: `tests/unit/fixtures/test-<module>.bicep`
2. Create parameters: `tests/unit/fixtures/params-<module>.json` (module-specific params only)
3. Add module to `MODULES` list in `tests/unit/test_modules.py`:
   ```python
   MODULES = [
       ...
       ('newmodule', 'test-newmodule.bicep', 'params-newmodule.json'),
   ]
   ```
4. Mock all dependencies in the test wrapper
5. All standard tests (compilation, parameter validation, what-if) will run automatically

**Note**: `resourceGroupName` and `location` are automatically read from `tests/fixtures/params.dev.json` - don't include them in module-specific params files.

See `tests/unit/README.md` for detailed instructions.

## Requirements

- Python 3.x
- pytest
- Azure CLI (`az`)
- Bicep CLI (via Azure CLI)
- shellcheck (optional, for `test_shell_scripts.py`)

## CI/CD Integration

Tests are designed to run in CI/CD pipelines:
- **Unit tests**: Fast, no Azure credentials needed for compilation tests
- **E2E what-if**: Requires Azure CLI login and pre-existing resource group
- **E2E actual deployment**: Opt-in only, requires explicit configuration, automatic RG management
