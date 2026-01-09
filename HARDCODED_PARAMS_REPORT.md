# Hardcoded Parameters Report

## Summary
This report lists all modules with hardcoded parameter defaults that should be removed.

## 1. Tags Parameter (default: `{}`)

All modules below have `param tags object = {}` but tags are always passed from `main.bicep`. These defaults should be removed:

- ✅ **network.bicep** (line 19) - tags passed from main.bicep line 224
- ✅ **dns.bicep** (line 7) - tags passed from main.bicep line 236
- ✅ **bastion.bicep** (line 16) - tags passed from main.bicep line 512
- ✅ **app.bicep** (line 13) - tags passed from main.bicep line 367
- ✅ **kv.bicep** (line 29) - tags passed from main.bicep line 257
- ✅ **public-ip.bicep** (line 10) - tags passed from main.bicep line 379
- ✅ **automation.bicep** (line 16) - tags passed from main.bicep line 476
- ✅ **diagnostics.bicep** (line 13) - tags passed from main.bicep line 194
- ✅ **cognitive-services.bicep** (line 29) - tags passed from main.bicep line 461
- ✅ **acr.bicep** (line 29) - tags passed from main.bicep line 325
- ✅ **identity.bicep** (line 10) - tags passed from main.bicep line 207
- ✅ **search.bicep** (line 32) - tags passed from main.bicep line 440
- ✅ **waf-policy.bicep** (line 16) - tags passed from main.bicep line 395
- ✅ **storage.bicep** (line 33) - tags passed from main.bicep line 304
- ✅ **psql-roles.bicep** (line 28) - tags passed from main.bicep line 497

## 2. VM Image Parameters in vm-jumphost.bicep

These parameters have hardcoded defaults but are not passed from `main.bicep`:

- ⚠️ **imagePublisher** = `'Canonical'` (line 42)
- ⚠️ **imageOffer** = `'0001-com-ubuntu-server-jammy'` (line 45)
- ⚠️ **imageSku** = `'22_04-lts-gen2'` (line 48)
- ⚠️ **imageVersion** = `'latest'` (line 51)

**Decision needed**: Should these be:
- Option A: Removed and passed from main.bicep (and params.dev.json)?
- Option B: Kept as defaults (they're infrastructure-level constants)?

## 3. psql-roles.bicep Parameters

These parameters have empty string defaults but are passed from `main.bicep`:

- ✅ **automationId** = `''` (line 22) - passed from main.bicep line 495
- ✅ **automationName** = `''` (line 25) - passed from main.bicep line 496

These defaults should be removed since they're always provided.

## Total Count

- **15 modules** with hardcoded `tags` defaults (should be removed)
- **1 module** (vm-jumphost) with **4** VM image parameter defaults (decision needed)
- **1 module** (psql-roles) with **2** parameter defaults (should be removed)

## Recommendation

1. Remove all `tags` defaults from all 15 modules listed above
2. Remove `automationId` and `automationName` defaults from psql-roles.bicep
3. Decide on VM image parameters - recommend Option A (move to main.bicep/params.dev.json) for consistency
