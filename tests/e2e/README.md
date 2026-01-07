# End-to-End Tests for main.bicep

This directory contains full-scope tests for the complete `main.bicep` deployment.

## Structure

```
tests/e2e/
  fixtures/
    params.dev.json          # Full deployment parameters
  test_main.py              # Full-scope test cases
```

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

## Cleanup

If you run actual deployment tests, remember to clean up resources:
```bash
az group delete --name <resource-group-name> --yes --no-wait
```

