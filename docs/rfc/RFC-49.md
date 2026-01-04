# 📜 Versioning

**RFC ID:** RFC-49  
**Status:** Accepted  
**Type:** Standard  
**Owning Team:** Platform

**URL:** https://www.notion.so/2d5309d25a8c80dda14de1b053fd6e95

---

# Decision:
Platform will use SemVer `v{major}.{minor}.{patch}` at the overall release manifest level. Each component will have its own versioning. Manifest will establish the relationship between the platform version and the versions of the components in the platform.

# Proposal
## 1. Versioning Scheme
- At the manifest level 
	- SemVer `v{major}.{minor}.{patch}` at the overall release manifest level. 
		- **Patch: **Bug fixes only. 
		- **Minor**: backward-compatible features
		- **Major**: Major features / breaking changes / incompatible upgrades
- Component level 
	- SemVer `v{major}.{minor}.{patch}` .
- Images / OCI artifacts 
	- All images are tagged with both version (`v1.4.2`) and `latest`.
	- Marketplace deployment (Day-0) and streaming updates (Day-2) pull images using the `latest` tag.
	- Version numbers in the manifest determine update eligibility by comparing `manifest.component.version` against `registry.component.currentVersion`.
	- Digests provide immutability and auditability but are not used for deployment orchestration.
- New components
	- Streaming updates can install new components if the component's `deploymentRunbook` exists and required infrastructure is in place.
	- New infrastructure (resource types not supported by existing runbooks, new subnets, etc.) requires a new marketplace offer.

## 2. Release Manifest
- The Release Manifest is a versioned, immutable JSON document that defines the exact set of artifacts (container images and OCI artifacts)  
	- Is the single source of truth for platform versions
	- Defines component-version to platform-version mappings
- Component identity scope
	- Component names in the release manifest are stable and immutable across platform versions; renaming a component requires treating it as a new logical component.
	- Components in the release manifest are keyed by component name.
	- During marketplace deployment and registry bootstrap, each manifest component name is mapped to a unique instance-scoped componentId

### **2.1 Release Manifest Schema**
```json
{
  "schemaVersion": "1.0",
  "releaseVersion": "1.4.2",
  "channel": "stable",
  "releasedAtUtc": "2026-01-12T10:00:00Z",
  "components": {
    "name": "airbyte-adls-connector",
    "componentPath": "/app/studio",
    "rtype": "managedClusters",
    "artifactType": "container",
    "deploymentRunbook": "...",
    "healthPolicy": {
      "healthEndpointType": "API | runbook | Unknwown",
      "healthEndpoint": "/health"
    },
    "version": "4.5.3",
    "artifactRef": "acceleratedata.io/vibedata/images@sha256:abc123"
  }
}
```

---

## 2. Release Manifest Storage
The publisher is the source of truth for the release manifest.
- **Managed Application Storage** – During both Marketplace deployment and streaming updates, the release manifest is copied verbatim into the managed application's artifact storage (Azure Blob Storage). This locally stored manifest becomes the authoritative manifest for that instance, and all runtime decisions (component bootstrap, upgrades, and health convergence) are driven exclusively from it.
- **Immutability** – Once persisted into the managed application, a manifest is treated as immutable and is never modified in-place. Platform version changes are effected only by replacing the manifest via the publisher-driven manifest-update runbook as part of the streaming updates flow.

The following scenarios describe how the manifest file is made available to the managed application:
- Marketplace Deployment – Marketplace deployment reads the manifest via a deployment-time pull from the Publisher ACR (see RFC-43 for Day-0 bootstrap authentication). The manifest is published as an OCI artifact and additionally tagged as `latest` per marketplace offer and release channel to support deterministic Day-0 bootstrap.
- Streaming Updates – During streaming updates, the managed application pulls the target release manifest from the Publisher ACR using the same short-lived, instance-scoped ACR token already provisioned for artifact pulls. The manifest is then persisted as a versioned, immutable file in the managed application's artifact storage; the registry's desiredVersion determines which manifest is active.

---

# Open Questions
	-

