# 📜 Developer and Release Pipeline Architecture

**RFC ID:** RFC-66  
**Status:** In Review  
**Type:** Standard  
**Owning Team:** Platform

**URL:** https://www.notion.so/2d9309d25a8c8046b2dfff34ea740661

---

# Decision:
1. GitHub is the single platform for source control, CI/CD (GitHub Actions), and artifact storage (GHCR + Releases).
2. GitHub Flow (main + feature branches) for all repositories.
3. Publisher flow uses branch-to-ACR mapping with Terraform for deployment.
4. Managed App services flow uses manifest repo for RC coordination.
5. Managed App IaC uses monthly release cadence with accumulated changes.
6. Ephemeral RGs created for PR validation using mixed tags (`:feature-{name}` for changed, `:latest` for rest).
7. Per-developer RGs are developer-managed with budget tracking.
8. RC created on merge to `main` in manifest repo; promoted to stable via label.
9. Partner Center Bicep templates contain no hardcoded tags.

---

# Summary
Defines the repository structure, branching strategy, and release pipeline for VibeData using GitHub as the single platform for source control, CI/CD, and artifact storage. Uses GitHub Flow for all repositories with two distinct deployment flows: Publisher (GitHub Flow → ACR → Terraform) and Managed App (GitHub Flow → ACR → Manifest Repo → GitHub Artifact Store → Production).

---

# Context
- VibeData consists of 9 repositories spanning Publisher and Managed App components.
- Publisher services deploy to publisher-owned infrastructure using Terraform with state management.
- Managed App services deploy to customer tenants via Azure Marketplace using Bicep without state.
- Developers need isolated environments mimicking production topology.
- Release candidates require validation before production promotion.
- Production releases must be immutable and auditable.
- Marketplace IaC requires monthly release cadence to align with Partner Center submission cycles.

---

# Proposal
## 1. Repository Structure
| Category | Repository | Purpose |
|----------|------------|---------|
| Publisher | `publisher_services` | Publisher engines (Provisioning, TLS, Registry) |
| Publisher | `publisher_iac` | Terraform for Publisher infrastructure |
| Managed App | `platform_services` | Core platform services (Health, Registry, Update) |
| Managed App | `studio` | Studio application |
| Managed App | `studio_agents` | Studio AI agents |
| Managed App | `control_panel` | Control Panel application |
| Managed App | `assurance_agents` | Assurance agents |
| Managed App | `marketplace_iac` | Bicep templates for Marketplace deployment |
| Managed App | `manifest` | Manifest and RC coordination |

---

## 2. Platform
| Function | Platform |
|----------|----------|
| Source Control | GitHub |
| CI/CD | GitHub Actions |
| Container Registry (Dev) | Azure Container Registry |
| Container Registry (Prod) | Azure Container Registry |
| Artifact Store | GitHub (GHCR + Releases) |

---

## 3. Branching Strategy
GitHub Flow for all repositories: `main` is the only long-lived branch.

| Branch | Purpose | Lifetime | **Merges To** |
|--------|---------|----------|---------------|
| `main` | Production-ready code | Permanent | - |
| `feature/*` | New features, bug fixes | Short-lived | `integration/*` or `main` |
| `integration/*` | Cross-repo testing | Short-lived | `main` |

---

## 4. Publisher Flow
GitHub Flow with branch-to-ACR mapping. Terraform deploys by referencing image tags.

### 4.1 Branch to ACR Mapping
| Branch | ACR | Tag Pattern |
|--------|-----|-------------|
| `feature/*` | Dev ACR | `:feature-{name}` |
| `main` | Prod ACR | `:{version}` + `:latest` |

### 4.2 Flow Steps
| Step | Trigger | Action | Target |
|------|---------|--------|--------|
| 1 | Push to `feature/*` | CI pushes image | Dev ACR `:feature-{name}` |
| 2 | PR to `main` | CI creates ephemeral RG, runs tests | Ephemeral Publisher RG |
| 3 | Merge to `main` | CI pushes image | Prod ACR `:{version}` |
| 4 | Merge to `main` in `publisher_iac` | Terraform apply | Prod Publisher RG |

---

## 5. Managed App Flow — Services
GitHub Flow with manifest repo for RC coordination. Single manifest aggregates all 5 service repos.

### 5.1 Flow Steps
| Step | Trigger | Action | Target |
|------|---------|--------|--------|
| 1 | Push to `feature/*` | CI pushes image | Dev ACR `:feature-{name}` |
| 2 | Manual | `deploy-dev.sh` (Terraform) | Dev Managed App RG |
| 3 | PR to `main` | CI creates ephemeral RG with mixed tags | Ephemeral RG |
| 4 | Merge to `main` | CI pushes image | Dev ACR `:latest` |
| 5 | Manual | PR to manifest repo with updated versions | Manifest repo |
| 6 | Merge to `main` in manifest repo | CI copies images to GHCR, creates RC | GHCR `:{version}-rc.{n}` |
| 7 | Manual | `deploy-release.sh` | Release Managed App RG |
| 8 | Label `promote:stable` | CI retags RC → stable | GHCR `:{version}` |
| 9 | Label `promote:stable` | CI copies images | Prod ACR `:{version}` |

### 5.2 Ephemeral RG — Mixed Tags
| Image | Tag Used | Reason |
|-------|----------|--------|
| Changed in PR | `:feature-{name}` | Test the actual changes |
| Not changed | `:latest` | Stable baseline |

### 5.3 Dev ACR Tag Lifecycle
| Branch | Tag | Lifecycle |
|--------|-----|-----------|
| `feature/*` | `:feature-{name}` | Temporary, cleaned up |
| `integration/*` | `:integration-{name}` | Temporary, cleaned up |
| `main` | `:latest` | Rolling, always current |

---

## 6. Managed App Flow — IaC
GitHub Flow with monthly release cadence. Changes accumulate on `main` and are released monthly.

### 6.1 Flow Steps
| Step | Trigger | Action | Target |
|------|---------|--------|--------|
| 1 | PR to `main` | CI deploys Bicep to ephemeral RG | Ephemeral RG |
| 2 | Merge to `main` | Changes accumulate | — |
| 3 | Monthly: Label `release:{version}` | CI packages IaC as RC | GitHub Release RC |
| 4 | Manual | `deploy-release.sh` | Release Managed App RG |
| 5 | Label `promote:stable` | CI retags RC → stable | GitHub Release Stable |
| 6 | Label `promote:partner-center` | Submit to Partner Center | Marketplace Offer |

### 6.2 Principle
IaC repo tests infrastructure code only. It pulls stable service images (`:latest` for ephemeral, GHCR RC for release).

---

## 7. Manifest Repo
Coordinates RC creation across all 5 service repos.

### 7.1 Manifest Schema
```json
{
  "schemaVersion": "1.0",
  "releaseVersion": "1.4.2",
  "components": [
    {
      "name": "platform-services",
      "repo": "platform_services",
      "tag": "latest",
      "digest": "sha256:abc123"
    }
  ]
}
```

---

## 8. Cross Repo integration
### 8.1 When to Use
| Scenario | Use Integration Branch? |
|----------|-------------------------|
| Single repo change | No — use ephemeral RG from PR |
| Cross-repo feature (2+ repos) | Yes |
| Monthly marketplace release prep | Yes |
| Hotfix | No — direct to main |

### 8.2 Flow
| Step | Action | Target |
|------|--------|--------|
| 1 | Create `integration/{name}` from `main` in each repo | Integration branches |
| 2 | Merge `feature/*` branches into `integration/{name}` | Integration branches |
| 3 | CI deploys all integration branches to Integration RG | `vd-integration-{name}` |
| 4 | Fix issues directly on integration branch | Integration branches |
| 5 | Merge `integration/{name}` → `main` in each repo | Main branches |
| 6 | Delete integration branches and RG | Cleanup |

### 8.3 Integration RG
| Aspect | Value |
|--------|-------|
| Naming | `vd-integration-{name}` |
| Lifecycle | Manual create, manual delete |
| Owner | Release Manager or Tech Lead |
| Images | Dev ACR `:integration-{name}` |

### 8.4 Key Rules
1. Integration branch always created from `main`
2. Feature branches merge into integration (not the other way)
3. Integration merges directly to `main` after validation
4. Feature branches are deleted after merging to integration

---

## 9. Deployment Model
### 9.1 Principle
- **Single Bicep codebase** — same `marketplace_iac` Bicep modules used in all environments
- **Terraform wraps Bicep** — Terraform handles orchestration, state, and tag injection via `azurerm_resource_group_template_deployment`
- **Bicep has no hardcoded tags** — tags passed as parameters from Terraform
- **Marketplace deployment** — Azure Marketplace calls Bicep directly (no Terraform), customer controls tags

### 9.2 Deployment by Environment
| Environment | Orchestrator | IaC | Tags Applied By |
|-------------|--------------|-----|-----------------|
| Per-developer RG | Terraform | Bicep | Terraform |
| Ephemeral RG | Terraform (CI) | Bicep | Terraform |
| Integration RG | Terraform (CI) | Bicep | Terraform |
| Release RG | Terraform | Bicep | Terraform |
| Production (Marketplace) | Azure Marketplace | Bicep | Customer control |

---

## 10. Resource Group Strategy
### 10.1 RG Types
| RG Type | Naming | Lifecycle | Cleanup |
|---------|--------|-----------|---------|
| Per-developer | `vd-dev-{username}-managed` | Long-lived | Developer manual, budget tracked |
| Ephemeral | `vd-ephemeral-{pr-number}` | PR lifecycle | Auto-delete on PR close |
| Integration | `vd-integration-{name}` | Manual | Manual delete after testing |
| Release | `vd-release-managed` | Long-lived | No cleanup |

### 10.2 Ephemeral RG Lifecycle
| Trigger | Action |
|---------|--------|
| PR to `main` opened | CI creates RG |
| PR merged | CI deletes RG |
| PR rejected/closed | CI deletes RG |

### 10.3 RG Tagging (Dev/Ephemeral Only)
| Tag | Value | Set By |
|-----|-------|--------|
| `owner` | `ci` or `{username}` | GitHub Actions |
| `purpose` | `ephemeral`, `dev`, `release` | GitHub Actions |
| `pr` | PR number (ephemeral only) | GitHub Actions |
| `repo` | Repository name | GitHub Actions |
| `created` | ISO timestamp p | GitHub Actions |
| `workflow_run_id` | GitHub Actions run ID | GitHub Actions |

Bicep templates contain no hardcoded tags. Terraform injects tags as parameters for dev/ephemeral/integration/release environments. For Marketplace (production) deployments, Azure calls Bicep directly and customers control their own tags via the portal.

---

## 11. State Management
| Environment | Publisher | Managed App |
|------------|-----------|-------------|
| Dev | Terraform: `dev` | Terraform: `dev-{username}` |
| Ephemeral | CI-managed | CI-managed |
| Production | Terraform: `prod` | Marketplace (no state) |

---

## 12. Retention Policy
| Registry | Retention |
|----------|-----------|
| Dev ACR | Current + last version per image |
| GHCR | Current + last RC, all stable versions |
| Prod ACR | All stable versions (no cleanup) |

---

## 13. Cost Control
| RG Type | Control |
|---------|---------|
| Ephemeral | Auto-delete on PR close |
| Per-developer | Azure budget alerts per developer |
| Release | Shared budget, monitored |

---

## 14. ACR Topology
**Note:** Prod ACR in the context of this RFC means the publisher public ACR which is referenced by the Bicep scripts in the marketplace offer.

| ACR | Purpose | Used By |
|-----|---------|---------|
| Dev ACR | Development and feature testing | Publisher + Managed App |
| Prod ACR | Production artifacts, referenced by marketplace Bicep | Publisher + Managed App |
| GHCR | Managed App artifact store (RC and stable) | Managed App only |

---

## 15. Access Control
| Action | Who | Approval |
|--------|-----|----------|
| Push to Dev ACR | Any developer | None |
| Push to Prod ACR | GitHub Actions | PR approval |
| Create RC (merge to main in manifest) | Developer | PR approval |
| Label `release:{version}` (IaC) | Release Manager | Tech Lead |
| Label `promote:stable` | Release Manager | Tech Lead + PM |
| Label `promote:partner-center` | Release Manager | Tech Lead + PM |
| Partner Center publish | Release Manager | Microsoft review |

---

## 16. Scripts
| Script | Purpose |
|--------|---------|
| `deploy-dev.sh` | Terraform deploy from Dev ACR to per-developer RG |
| `deploy-release.sh` | Simulated marketplace deploy from GHCR RC to Release RG |

---

# Impact
- Single platform (GitHub) for source, CI/CD, and artifacts
- Simplified branching with GitHub Flow (`main` only)
- Clear separation between Publisher and Managed App flows
- Manifest repo enables coordinated releases across 5 service repos
- Monthly IaC releases align with Partner Center submission cycles
- Developer isolation via Terraform workspaces
- Ephemeral RGs with mixed tags enable proper integration testing
- Release validation via simulated marketplace deployment
- Label-based promotion provides controlled production releases
- Immutable artifacts in GitHub ensure reproducibility

---

# Open Questions
- None

