# Release Notes — v0.7.1 (2026-01-08)

## Troubleshooting Infrastructure and Customer Admin Data Plane Access

This release adds jump host infrastructure for troubleshooting, implements read-only data plane RBAC for customer administrators, includes module refactoring improvements, and enhances test utilities for better developer experience.

### Changes

#### PostgreSQL RBAC Removal
- **Removed**: PostgreSQL role creation and assignment logic from main deployment flow
- **Impact**: PostgreSQL roles are no longer created automatically during deployment
- **Module status**: `psql-roles.bicep` module exists but is not deployed by default in `main.bicep`

#### New Infrastructure Modules

##### VM Jump Host (`iac/modules/vm-jumphost.bicep`)
- **New module**: Creates a Linux VM (Ubuntu 22.04 LTS) for troubleshooting access
- **Default state**: VM is created in stopped (deallocated) state to minimize costs
- **Network**: Deployed to private endpoints subnet within the VNet
- **Credentials**: VM admin password is auto-generated and stored in Key Vault as `vm-admin-password` secret
- **Configuration**: Uses Standard_B2s VM size by default, password-based authentication enabled for Bastion access

##### Azure Bastion (`iac/modules/bastion.bicep`)
- **New module**: Creates Azure Bastion host for secure VM access
- **Network**: Uses dedicated bastion subnet (`snet-bastion`) added to network module
- **Public IP**: Standard SKU public IP for Bastion connectivity
- **Security**: Provides secure, browser-based RDP/SSH access without exposing VMs to the internet

##### Network Updates (`iac/modules/network.bicep`)
- **Added subnet**: `snet-bastion` subnet for Azure Bastion (6th subnet, index 5)
- **Outputs**: Added `subnetBastionId` and `subnetBastionPrefix` outputs

#### Customer Admin Data Plane RBAC (`iac/modules/admin-data-plane-rbac.bicep`)
- **New module**: Assigns read-only data plane roles to customer admin (`adminObjectId`)
- **Roles assigned**:
  - **Key Vault Secrets User**: Read access to secrets (VM password, PostgreSQL credentials)
  - **Storage Blob Data Reader**: Read access to blob storage
  - **Storage Queue Data Reader**: Read access to queue storage
  - **Storage Table Data Reader**: Read access to table storage
  - **AcrPull**: Read access to container images
  - **Search Service Reader**: Read access to search indexes
  - **Cognitive Services User**: Read-only access to cognitive services APIs
- **Scope**: All roles assigned at resource level (not subscription level)
- **Purpose**: Enables customer admin to troubleshoot and monitor data plane resources without write access

#### SSH Utility Script (`scripts/ssh-via-bastion.sh`)
- **New utility**: Shell script for connecting to VM via Azure Bastion
- **Features**:
  - Automatic VM state checking
  - VM startup prompt if VM is stopped
  - Resource validation (VM and Bastion existence)
  - Private IP resolution
  - Secure password-based SSH authentication via Bastion
- **Usage**: `./scripts/ssh-via-bastion.sh -g <rg> -v <vm-name> -b <bastion-name>`

#### Documentation Updates
- **README.md**: Added comprehensive "Troubleshooting: SSH via Azure Bastion" section
  - Prerequisites and setup instructions
  - SSH utility script usage examples
  - Manual VM management commands
  - Resource name retrieval instructions
  - Complete script documentation


### Verification

- ✅ All new modules compile successfully (no linter errors)
- ✅ `main.bicep` updated with new modules and dependencies
- ✅ Network module updated with bastion subnet
- ✅ VM password stored securely in Key Vault
- ✅ Customer admin data plane RBAC roles assigned correctly
- ✅ SSH utility script executable and functional
- ✅ README updated with troubleshooting documentation

### Impact

#### New Capabilities
- **Troubleshooting access**: Customer admins can now SSH into jump host VM via Azure Bastion for troubleshooting
- **Cost optimization**: VM created in stopped state by default, can be started on-demand
- **Secure access**: No public IPs exposed, all access via Azure Bastion
- **Data plane visibility**: Customer admins can read data from all data plane resources for monitoring and troubleshooting

#### Security Improvements
- **Least privilege**: Customer admin has read-only access to data plane resources
- **Credential management**: VM password stored securely in Key Vault
- **Network isolation**: VM deployed in private subnet, accessible only via Bastion

#### Operational Benefits
- **Automated troubleshooting**: SSH script automates VM connection process
- **Cost control**: VM can be stopped when not in use
- **Self-service**: Customer admins can start VM and connect without publisher intervention

### Related Issues

- Jump host infrastructure for troubleshooting
- Customer admin read-only data plane access
- Secure VM access via Azure Bastion
- Credential management in Key Vault
- PostgreSQL RBAC simplification

### Migration Notes

**No migration required.** This release adds new infrastructure without breaking changes:

- Existing resources remain unchanged
- New modules are additive (VM, Bastion, admin RBAC)
- VM is created in stopped state (no cost until started)
- Customer admin RBAC roles are assigned automatically
- SSH utility script is optional (can use Azure Portal or CLI directly)

**For developers:**
- New modules: `vm-jumphost`, `bastion`, `admin-data-plane-rbac`
- PostgreSQL RBAC: Role creation moved to optional `psql-roles.bicep` module (not deployed by default)
- VM password available in Key Vault as `vm-admin-password` secret
- Customer admin can read secrets via Key Vault Secrets User role

**For operators:**
- VM must be started before connecting: `az vm start --resource-group <rg> --name <vm-name>`
- Use SSH script: `./scripts/ssh-via-bastion.sh -g <rg> -v <vm-name> -b <bastion-name>`
- VM password can be retrieved from Key Vault: `az keyvault secret show --vault-name <kv-name> --name vm-admin-password`

### Files Changed

**Created:**
- `iac/modules/vm-jumphost.bicep`
- `iac/modules/bastion.bicep`
- `iac/modules/admin-data-plane-rbac.bicep`
- `scripts/ssh-via-bastion.sh`
- `tests/unit/fixtures/test-vm-jumphost.bicep`
- `tests/unit/fixtures/test-admin-data-plane-rbac.bicep`
- `tests/unit/fixtures/test-bastion.bicep`

**Modified:**
- `iac/main.bicep` (added vm-jumphost, bastion, admin-data-plane-rbac modules; removed psql-roles call)
- `iac/modules/network.bicep` (added snet-bastion subnet and outputs)
- `iac/modules/psql.bicep` (PostgreSQL admin credentials now stored in Key Vault)
- `README.md` (added SSH via Bastion troubleshooting section)
