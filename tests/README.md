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

```bash
# Run what-if tests (default, safe)
pytest tests/e2e/

# Run actual deployment (requires opt-in)
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
- **Actual deployment mode** (opt-in): Creates real resources
  - Set `ENABLE_ACTUAL_DEPLOYMENT=true` to enable
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

## CI/CD Integration

Tests are designed to run in CI/CD pipelines:
- Unit tests: Fast, no Azure credentials needed for compilation tests
- E2E what-if: Requires Azure CLI login but no actual deployment
- E2E actual deployment: Opt-in only, requires explicit configuration

