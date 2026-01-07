# End-to-End Tests for main.bicep

This directory contains full-scope tests for the complete `main.bicep` deployment.

## Structure

```
tests/e2e/
  state_check/              # What-if drift detection utilities
    what_if.sh             # Run what-if and save JSON output
    diff_report.py         # Summarize what-if changes
  validator/                # Post-deployment validation tools
    collect_actual_state.py # Collect actual Azure resource state
    compare_expectation.py  # Compare actual vs expected state
    expected/              # Expected state templates
    test_*.py              # Validation test files
  test_main.py             # Full-scope test cases
```

## Prerequisites

Before running E2E tests, you must authenticate with Azure CLI:

### 1. Authenticate with Azure CLI
```bash
az login
```

### 2. (Optional) Configure Azure Context in Params File
You can specify Azure context information in `tests/fixtures/params.dev.json` metadata section:

```json
{
  "metadata": {
    "subscriptionId": "your-subscription-id-here",
    "resourceGroupName": "vd-rg-dev-abc12345",
    "location": "eastus"
  },
  "parameters": {
    ...
  }
}
```

**Note**: 
- `subscriptionId` - Used to set the active subscription via `az account set` (optional)
- `resourceGroupName` and `location` - ARM-provided context in managed applications. For testing, extracted from metadata to create/set the resource group context
- If metadata is not provided, tests will use your current Azure CLI context

### 3. Verify Authentication and Check Subscription
```bash
az account show
```

Verify that the correct subscription is selected and authentication is active.

### 4. Run E2E Tests
```bash
pytest tests/e2e/
```

**Note**: If you skip authentication, tests will automatically skip with a message indicating Azure CLI is not configured.

### Alternative: Service Principal (for CI/CD)

For CI/CD pipelines, use a service principal instead:

```bash
az login --service-principal \
  --username <app-id> \
  --password <password> \
  --tenant <tenant-id>
```

Or use managed identity if running in Azure.

## Running Tests

```bash
# Run what-if tests (default, safe)
pytest tests/e2e/

# Run actual deployment tests (requires opt-in)
ENABLE_ACTUAL_DEPLOYMENT=true pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

## Test Modes

### What-If Mode (Default)
- Validates deployment plan without creating resources
- Fast and safe
- No actual Azure resources created
- Requires Azure CLI login

### Actual Deployment Mode (Opt-In)
- Creates real Azure resources
- Validates actual resource properties
- **WARNING**: This creates real resources and incurs costs!
- Requires `ENABLE_ACTUAL_DEPLOYMENT=true` environment variable
- Requires Azure credentials and subscription access

## Usage

### What-If Testing (Recommended)
```bash
pytest tests/e2e/test_main.py::TestMainBicep::test_what_if_succeeds
```

### Actual Deployment (Manual/CI Only)
```bash
# Set environment variable
export ENABLE_ACTUAL_DEPLOYMENT=true

# Run actual deployment test
pytest tests/e2e/test_main.py::TestMainBicep::test_actual_deployment
```

## Resource Group Management

### Automatic Resource Group Management

When `ENABLE_ACTUAL_DEPLOYMENT=true`, the test harness **automatically manages** the resource group:

- **Before each test**: Creates a fresh resource group (deletes existing one if present)
- **After each test**: Deletes the resource group and waits for completion
- **On failure**: Ensures cleanup happens even if tests fail
- **Scope**: One resource group per test function (`scope="function"`)

### Resource Group Behavior

1. **Delete and Recreate**: If the resource group exists, it's deleted first, then recreated
2. **Wait for Completion**: All operations wait for Azure to complete (no `--no-wait`)
3. **Timeout Protection**: 
   - Creation timeout: 5 minutes
   - Deletion timeout: 10 minutes
4. **Failure Handling**: Cleanup always runs, even if tests fail

### Manual Cleanup (if needed)

If automatic cleanup fails or you need to manually clean up:
```bash
az group delete --name <resource-group-name> --yes
```

**Note**: With automatic resource group management enabled, manual cleanup should rarely be needed.

