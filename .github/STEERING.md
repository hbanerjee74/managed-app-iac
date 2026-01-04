# Repository Steering: Managed App IaC

**Purpose:**
This repository contains the Bicep-based Infrastructure-as-Code (IaC) to deploy the Managed Application infrastructure described in PRD-30 ("IaC for Managed Application Infrastructure Deployment"). The steering doc defines the repository mission, scope boundaries, CI gating, contribution rules, and deployment verification expectations so that maintainers and reviewers have a single source of truth for governance.

---

## Mission
Deploy deterministic, idempotent, and testable Bicep templates that provision the full Managed Resource Group (MRG) infrastructure required by VibeData platform services, in alignment with PRD-30 and the referenced RFCs (RFC-13, RFC-42, RFC-51, RFC-60, RFC-64, RFC-66, RFC-71, RFC-72).

## Scope (What this repo is responsible for)
- Author and maintain the `iac/` Bicep modules and `main.bicep` subscription-scoped entrypoint.
- Ensure parameters conform to RFC-64 and are bound exactly (name + casing) into templates.
- Implement idempotent deployments that complete in reasonable time (target < 30 minutes for Phase 1).
- Provide automated pre-merge CI checks (Bicep build/validation, unit tests, parameter checks, what-if/state-check utilities).
- Provide post-deployment verification utilities to assert the actual Azure resource state matches an expected JSON spec for the parameter set.

## Out of scope (per PRD-30)
- AKS cluster deployment, application artifacts, or runtime services.
- TLS certificate issuance and binding, DNS A-record creation/validation, publisher provisioning, marketplace end-to-end flows, or publisher callbacks.
- Any runtime health/functional validation beyond the resource-level verification defined in the Post-Deployment Verification section.

## Acceptance Criteria (Repository-level gating)
PRs that modify IaC must satisfy the following before merge:
- Bicep templates build successfully: `az bicep build iac/main.bicep --stdout`
- Parameter presence checks pass (`pytest tests/test_params.py`) and any new parameters are documented in `iac/params.*.json` sample files.
- `tests/state_check/what_if.sh` and `tests/state_check/diff_report.py` run without errors on sample parameter sets (if changes affect resource shapes, update expected diff files).
- Unit and lint tests pass (`pytest -q`, `bicep lint` if available).
- PR includes updated Acceptance Criteria mapping (which FRs/NFRs were impacted and how tests validate them).

---

## PR Checklist (use as PR template)
- [ ] PR description references PRD-30 and lists affected FR/NFR IDs
- [ ] Bicep build passes locally and in CI
- [ ] Parameter samples updated (`iac/params.*.json`) and `tests/test_params.py` updated if needed
- [ ] State-check/what-if expectations updated (if resource changes)
- [ ] Add/Update unit tests or smoke CI checks validating the change
- [ ] At least one reviewer listed from the owning team and approval from the repository Approver

## Branching & Release Flow
- Feature work: branch name `feature/<short-description>` or `fix/<short-description>`
- Release branches: `release/<semver>` if needed
- Merge strategy: Squash merges with PRs requiring at least one approving reviewer and passing CI
- Tagging: Use semantic tags for release artifacts when cutting release points for deployment

## CI & Checks
The canonical CI checks this repo enforces (examples to be implemented via GitHub Actions):
- Bicep build (fail fast if templates don't compile)
- Pytest unit tests (`tests/test_params.py`)
- What-If / state-check scripts (run against sample param files) and `diff_report.py` to detect drift
- Linting (Bicep and Python) and any static security checks
- Optionally: cost-estimate and deployment time heuristics for large changes

## Post-Deployment Verification
After a deployment is executed (manual or automated), run the Post-Deployment Verification script to assert resource presence and key configuration properties match an expected JSON spec for the parameter set.
- Location: `tests/state_check/` (what_if.sh, diff_report.py)
- The expected JSON spec should be checked in under `tests/state_check/expected/<param-set>.json` when necessary

## Ownership & Approvals
- **Repo Owner:** see PRD-30 metadata (maintainers and approvers should be added to CODEOWNERS if not already present)
- **Reviewers:** Changes that affect security, networking, or identity must be reviewed by the owning teams defined in RFC-42 and RFC-13
- **Approver:** Repository approver must sign off on releases

## Automation & Agents
- Automation should be focused on achieving PR gates and post-deploy verification, not on application publishing.
- Agent commands and GitHub Actions workflows should provide the following primitives:
  - `bicep:build` — compile templates
  - `tests:unit` — run pytest
  - `state_check:what-if` — run `tests/state_check/what_if.sh` and `diff_report.py` against sample params
  - `verify:postdeploy` — run resource verification against expected JSON

---

## Notes & References
- Source PRD: `docs/prd/PRD-30.md`
- RFC references: `docs/rfc/RFC-13.md`, `docs/rfc/RFC-42.md`, `docs/rfc/RFC-51.md`, `docs/rfc/RFC-60.md`, `docs/rfc/RFC-64.md`, `docs/rfc/RFC-66.md`, `docs/rfc/RFC-71.md`, `docs/rfc/RFC-72.md`
- Local test utilities: `tests/`, `tests/state_check/`, `tests/validator/` (placeholder)

---

If this steering draft looks good I can:
1. Add a PR template that enforces the checklist above.
2. Update `.github/agents/copilot-agent.yml` to reflect the agent commands aligned with these CI primitives.
3. Add a GitHub Actions workflow that runs the Bicep build, pytest, and state-check steps on PRs.

Please confirm which of these follow-ups you'd like me to take next.