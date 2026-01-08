# Test Harness

This directory contains the test harness for validating Bicep modules and deployments.

## Structure

```text
tests/
  unit/                    # Unit tests for individual modules
    fixtures/              # Test wrapper templates (no params files needed)
    helpers/               # Test utility functions
    test_modules.py        # Parameterized test file for all modules
  e2e/                     # End-to-end tests for main.bicep
    test_main.py          # Full-scope test cases
  fixtures/                # Shared test fixtures
    params.dev.json       # Single source of truth for RG name, location, and all parameters
  test_params.py          # Validates params.dev.json has required parameters
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

**Recommended workflow:**

1. **Run unit tests first** (auto-creates resource group if needed):

   ```bash
   pytest tests/unit/test_modules.py -v
   ```

2. **Run E2E what-if tests** (uses resource group from unit tests):

   ```bash
   pytest tests/e2e/
   ```

   **Verbose output options:**
   - `-v` or `--verbose` - Show test names (default with pytest.ini)
   - `-vv` - Extra verbose (show test names and assertions)
   - `-rs` - Show skip reasons
   - `-ra` - Show all test outcomes (passed, failed, skipped, etc.)

   Example with skip reasons:

   ```bash
   pytest tests/e2e/ -rs
   ```

3. **Run actual deployment** (opt-in, creates real resources):

   ```bash
   ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
   ```

   **Keep resource group for debugging/inspection:**

   ```bash
   ENABLE_ACTUAL_DEPLOYMENT=true KEEP_RESOURCE_GROUP=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
   ```

   When `KEEP_RESOURCE_GROUP=true`, the resource group is not deleted after the test completes. Useful for:
   - Inspecting deployed resources
   - Debugging deployment issues
   - Manual validation

   **Note**: Unit tests automatically create the resource group if it doesn't exist, so you can skip manual `az group create` when running the full test suite.

## Test Configuration

### Single Source of Truth: `tests/fixtures/params.dev.json`

Both unit tests and E2E tests read `resourceGroupName` and `location` from `tests/fixtures/params.dev.json`:

- **`metadata.resourceGroupName`** - Resource group name for all tests
- **`metadata.location`** - Azure region for all tests
- **`metadata.subscriptionId`** - (Optional) Subscription ID for E2E tests

**Why?** This ensures consistency across all tests and matches the managed application deployment model where ARM provides these values.

### Parameters

Unit tests **automatically use all parameters** from `tests/fixtures/params.dev.json`. No module-specific params files are needed - all parameters are merged automatically for all modules.

## Test Types

**Unit Tests** (`tests/unit/test_modules.py`):

- `test_bicep_compiles` - Validates Bicep syntax and compilation
- Parameter validation is handled automatically via shared params file
- `test_what_if_succeeds` - Runs Azure what-if to validate deployment plan
- `test_cidr_validation_valid_ranges` - (Network module only) Tests valid CIDR ranges (/16, /20, /24)
- `test_cidr_validation_invalid_prefix` - (Network module only) Tests invalid prefix ranges (/15, /14, /8, /25, /26, /30)
- `test_cidr_validation_invalid_format` - (Network module only) Tests invalid CIDR formats (missing prefix, invalid IP, etc.)

**E2E Tests** (`tests/e2e/test_main.py`):

- `test_bicep_compiles` - Validates main.bicep compilation
- Parameter validation is handled automatically via shared params file
- `test_what_if_succeeds` - Full-scope what-if validation
- `test_what_if_output_valid` - Validates what-if output is valid JSON
- `test_what_if_summary` - Validates what-if output structure
- `test_actual_deployment` - Actual deployment + post-deployment state check (opt-in only)
  - Deploys resources, then runs what-if to validate no unexpected deletions
  - Both steps happen in one test before fixture tears down the resource group

## Test Modes

### Unit Tests

- **Mode**: What-if only (no actual deployment)
- **Purpose**: Validate individual modules in isolation
- **Dependencies**: Mocked in test wrappers (`test-<module>.bicep`)
- **Resources**: None created (what-if only)
- **RG Management**: Automatically creates RG if missing (from shared params)
- **Azure CLI**: Required for what-if tests, optional for compilation tests

### E2E Tests

- **What-if mode** (default): Validates full deployment plan
  - **Resource Group**: Must exist (unit tests create it, or create manually)
  - Uses resource group name from `tests/fixtures/params.dev.json` → `metadata.resourceGroupName`
  - Test does NOT create or delete the resource group
  - **Azure CLI**: Required (for what-if operations)
- **Actual deployment mode** (opt-in): Creates real resources
  - Set `ENABLE_ACTUAL_DEPLOYMENT=true` to enable
  - **Resource Group**: Automatically created before each test and deleted after
  - **WARNING**: Creates real Azure resources and incurs costs!
  - **Azure CLI**: Required

## Test Files Explained

### `test_modules.py` (Unit Tests)

**Purpose**: Parameterized test suite for all Bicep modules.

**What it tests:**

- **Compilation**: Each module's test wrapper compiles successfully
- **Parameter files**: Module-specific param files exist and are valid JSON
- **What-if**: Azure what-if succeeds for each module (validates deployment plan)
- **CIDR Validation** (Network module only): Tests CIDR format and prefix length validation
  - Valid ranges: `/16`, `/20`, `/24` (should succeed)
  - Invalid prefixes: `/15`, `/14`, `/8`, `/25`, `/26`, `/30` (should fail)
  - Invalid formats: missing prefix, invalid IP, non-numeric prefix (should fail)
  
  **Note**: Invalid CIDR tests currently document expected behavior but may not fail during what-if validation. Invalid CIDRs will fail during actual deployment when `cidrSubnet` calculations are executed.

**Usage:**

```bash
# Run all tests for all modules
pytest tests/unit/test_modules.py -v

# Run tests for specific module
pytest tests/unit/test_modules.py -v -k "network"

# Run only compilation tests (no Azure CLI needed)
pytest tests/unit/test_modules.py -v -k "compiles"

# Run only what-if tests
pytest tests/unit/test_modules.py -v -k "what_if"

# Run CIDR validation tests (network module only)
pytest tests/unit/test_modules.py -v -k "cidr"
```

### `test_main.py` (E2E Tests)

**Purpose**: Full-scope tests for `main.bicep` deployment.

**What it tests:**

- **Compilation**: `main.bicep` compiles successfully
- **Parameters**: Parameter file exists and is valid JSON
- **What-if**: Full deployment what-if succeeds
- **What-if output**: What-if output is valid JSON
- **What-if summary**: What-if output can be parsed and summarized
- **Actual deployment**: (Opt-in) Creates real resources and validates state
  - Deploys `main.bicep` to create resources
  - Runs what-if against deployed resources to check for drift
  - Validates no unexpected deletions (indicates template matches deployed state)

**Usage:**

```bash
# Run what-if tests (default, safe)
pytest tests/e2e/

# Run actual deployment (opt-in)
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

### `test_params.py`

**Purpose**: Validates that `tests/fixtures/params.dev.json` contains all required parameters for `main.bicep`.

**What it checks:**

- All required parameters are present in the `parameters` section
- `metadata.resourceGroupName` and `metadata.location` are present

**Usage:**

```bash
pytest tests/test_params.py
```

**Note**: This is a code quality check, not a functional test.

## Resource Group Management

### Unit Test Resource Groups

- **Automatic creation**: Resource group is created if it doesn't exist
- **Source**: RG name and location from `tests/fixtures/params.dev.json` → `metadata`
- **No cleanup**: Resource group persists after tests (shared across test runs)

### E2E Tests - What-If Mode (Default)

- **Resource Group**: Must exist (unit tests create it, or create manually)
- **No automatic cleanup**: The test uses the existing resource group and does not delete it
- **Resource group name**: Configured in `tests/fixtures/params.dev.json` → `metadata.resourceGroupName`

**Recommended workflow:**

```bash
# 1. Run unit tests (creates RG automatically)
pytest tests/unit/test_modules.py -v

# 2. Run E2E tests (uses existing RG)
pytest tests/e2e/
```

**Alternative (manual RG creation):**

```bash
# Create resource group manually
az group create --name test-rg-managed-app --location eastus

# Update params.dev.json metadata.resourceGroupName to "test-rg-managed-app"

# Run tests
pytest tests/e2e/
```

### E2E Tests - Actual Deployment Mode (Opt-In)

- **Automatic creation**: Resource group is created before each test
- **Automatic cleanup**: Resource group is deleted after each test (even on failure)
- **Scope**: One resource group per test function (`scope="function"`)
- **Timeout protection**: 5 min creation, 10 min deletion timeouts
- **Delete and Recreate**: If the resource group exists, it's deleted first, then recreated
- **Wait for Completion**: All operations wait for Azure to complete (no `--no-wait`)

When `ENABLE_ACTUAL_DEPLOYMENT=true`:

- Test fixture automatically creates/deletes resource group
- No manual setup required
- Cleanup guaranteed even if tests fail

**Skip cleanup for debugging:**

Set `KEEP_RESOURCE_GROUP=true` to keep the resource group after tests complete:

```bash
ENABLE_ACTUAL_DEPLOYMENT=true KEEP_RESOURCE_GROUP=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

This is useful for:

- Inspecting deployed resources after tests
- Debugging deployment issues
- Manual validation of resources

**Warning**: Remember to manually delete the resource group when done:

```bash
az group delete --name <resource-group-name> --yes
```

## Adding New Module Tests

1. Create test wrapper: `tests/unit/fixtures/test-<module>.bicep`
2. Add module to `MODULES` list in `tests/unit/test_modules.py`:

   ```python
   MODULES = [
       ...
       ('newmodule', 'test-newmodule.bicep'),
   ]
   ```

3. Mock all dependencies in the test wrapper
4. All standard tests (compilation, what-if) will run automatically

**Note**: All parameters (including `resourceGroupName` and `location`) are automatically read from `tests/fixtures/params.dev.json`. No module-specific params files are needed.

See `tests/unit/README.md` for detailed instructions.

## Requirements

- **Python 3.x** with pytest installed
- **Azure CLI** (`az`) - Required for what-if tests, optional for compilation tests
- **Bicep CLI** (included with Azure CLI)

## Test Output Options

By default, pytest shows minimal output. Use these flags for more details:

- **`-v` or `--verbose`** - Show test names (configured in `pytest.ini`)
- **`-vv`** - Extra verbose (show test names and assertions)
- **`-rs`** - Show skip reasons (why tests were skipped)
- **`-ra`** - Show all test outcomes (passed, failed, skipped, xfailed, etc.)
- **`--tb=short`** - Shorter tracebacks (default with pytest.ini)
- **`--tb=long`** - Full tracebacks for debugging

**Examples:**

```bash
# Show which tests passed/failed/skipped with reasons
pytest tests/e2e/ -rs

# Extra verbose output
pytest tests/e2e/ -vv

# Show all outcomes
pytest tests/e2e/ -ra
```

## CI/CD Integration

Tests are designed to run in CI/CD pipelines:

- **Unit compilation tests**: Fast, no Azure credentials needed

```bash
pytest tests/unit/test_modules.py -v -k "compiles"
```

- **Unit what-if tests**: Requires Azure CLI login and subscription access

```bash
pytest tests/unit/test_modules.py -v -k "what_if"
```

- **E2E what-if**: Requires Azure CLI login and pre-existing resource group

```bash
pytest tests/e2e/
```

- **E2E actual deployment**: Opt-in only, requires explicit configuration, automatic RG management

```bash
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

### Authentication for CI/CD

For CI/CD pipelines, use service principal authentication instead of interactive login:

```bash
az login --service-principal \
  --username <app-id> \
  --password <password> \
  --tenant <tenant-id>
```

Or use managed identity if running in Azure (e.g., Azure Pipelines agents, GitHub Actions runners with Azure credentials).

## Troubleshooting

### Tests fail with "Azure CLI not configured"

- Run `az login` to authenticate
- Verify subscription: `az account show`
- Set subscription in `params.dev.json` → `metadata.subscriptionId`

### Resource group doesn't exist

- Run unit tests first: `pytest tests/unit/test_modules.py -v` (auto-creates RG)
- Or create manually: `az group create --name <rg-name> -l <location>`

### What-if tests fail

- Check Azure CLI authentication: `az account show`
- Verify resource group exists: `az group exists --name <rg-name>`
- Check parameter file: `pytest tests/test_params.py`

### Compilation tests fail

- Check Bicep syntax: `az bicep build --file iac/main.bicep`
- Verify module dependencies are correct
- Check test wrapper templates for syntax errors

### Resource group cleanup fails

If automatic cleanup fails or you need to manually clean up:

```bash
az group delete --name <resource-group-name> --yes
```

**Note**: With automatic resource group management enabled, manual cleanup should rarely be needed.
