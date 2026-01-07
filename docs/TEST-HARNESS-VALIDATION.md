# What We're Actually Testing with What-If

## What What-If Validates

### ✅ Template Validation
- **Bicep syntax**: Template compiles to valid ARM JSON
- **Parameter structure**: Parameters match template expectations
- **Azure API acceptance**: Azure Resource Manager accepts the template
- **Resource plan**: Shows what resources would be created/modified/deleted

### ✅ Basic Property Validation
- **SKU availability**: Validates SKUs are available in the region
- **Name formats**: Validates resource names meet Azure requirements
- **Required properties**: Validates required properties are present
- **Property types**: Validates property types match API expectations

## What What-If Does NOT Validate

### ❌ RFC-71 Compliance
- **Resource properties**: Doesn't verify properties match RFC-71 standards
- **Naming conventions**: Doesn't verify naming follows RFC-71 patterns
- **Security baselines**: Doesn't verify security settings per RFC-71
- **Tag standards**: Doesn't verify tags match RFC-71 requirements

### ❌ Module Logic
- **Module outputs**: Doesn't verify outputs are correct
- **Dependencies**: Doesn't verify module dependencies are wired correctly
- **Naming determinism**: Doesn't verify naming.bicep outputs are deterministic
- **Parameter constraints**: Doesn't verify min/max values, allowed values

### ❌ Actual Resource State
- **Resource creation**: Doesn't create resources, so can't validate actual state
- **Resource relationships**: Doesn't verify resources are correctly linked
- **RBAC assignments**: Doesn't verify role assignments are correct
- **Private endpoints**: Doesn't verify private endpoints are configured correctly

## Current Test Coverage

### What We Test Now
1. ✅ **Bicep compilation**: Template compiles successfully
2. ✅ **Parameter file validation**: JSON is valid, required params present
3. ✅ **What-if execution**: Azure accepts the template
4. ✅ **Resource creation plan**: Expected resources would be created
5. ✅ **No unexpected changes**: No unexpected resource modifications
6. ✅ **No deletions**: No resources would be deleted

### What We Should Add (Future)
1. **RFC-71 property validation**: Parse what-if output and validate properties
2. **Naming validation**: Verify naming outputs match RFC-71 patterns
3. **Output validation**: Verify module outputs match expected schemas
4. **Parameter constraint validation**: Test min/max values, allowed values
5. **Error scenario testing**: Test invalid inputs, missing params

## Limitations

### What-If Limitations
- **No actual deployment**: Can't verify resources work correctly
- **Limited property validation**: Only validates API acceptance, not standards compliance
- **No runtime validation**: Can't verify resources function correctly
- **Mock dependencies**: Module tests use mocked dependencies, so dependency wiring isn't fully validated

### When to Use Actual Deployment
Use actual deployment tests (`ENABLE_ACTUAL_DEPLOYMENT=true`) when you need to:
- Validate actual resource properties match RFC-71
- Verify resources are correctly configured
- Test resource relationships and dependencies
- Validate RBAC assignments
- Test private endpoint connectivity

**Note**: When `ENABLE_ACTUAL_DEPLOYMENT=true`, the test harness automatically:
- Creates a fresh resource group before each test (deletes existing if present)
- Deletes the resource group after each test completes
- Waits for all operations to complete (no `--no-wait`)
- Ensures cleanup even if tests fail
- Uses function scope (one resource group per test)

## Recommendations

1. **Keep what-if tests**: Fast, safe, catches syntax/API errors
2. **Add property validation**: Parse what-if output to validate RFC-71 compliance
3. **Use actual deployment sparingly**: Only for full-scope E2E tests, opt-in only
4. **Add post-deployment validation**: Use `collect_actual_state.py` to validate actual resources
5. **Test error scenarios**: Add tests for invalid inputs, missing params

