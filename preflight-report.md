# Azure Deployment Preflight Report

**Generated:** 2026-09-04T05:47:20Z
**Status:** ⚠️ Disabled template passed; enabled pilot is NO-GO

## Summary

| Property | Value |
|---|---|
| **Template** | `infra/ci-runner/aca/main.bicep` |
| **Parameters** | Generated privately and deleted by `preflight.ps1` |
| **Project type** | Standalone Bicep |
| **Scope** | Resource group, incremental what-if |
| **Target** | `RG-CERTIGO-CI`, West Europe |
| **Validation level** | `Provider` |
| **Pilot state tested** | `pilotEnabled=false` |

| Check | Status | Details |
|---|---|---|
| Bicep syntax | ✅ Pass | Bicep 0.44.1, no warnings after correction |
| Provider registration | ✅ Pass | App, OperationalInsights, Insights registered |
| What-if | ✅ Pass | 3 Create, 0 Modify, 0 Delete, 0 pilot Ignore |
| Permission check | ✅ Pass | Full `Provider` validation; no fallback |
| Enabled schema/permissions | ✅ Structural pass | 4 Create, including exactly 1 job |
| Enabled runtime | ⏭️ Blocked | Certigo image and GitHub App prerequisites are absent |

## Tools Executed

| Step | Command | Result |
|---|---|---|
| 1 | `az bicep build --file infra\ci-runner\aca\main.bicep --stdout` | Pass |
| 2 | `preflight.ps1` without `-EnablePilot` | Pass |
| 3 | Strict `validate-what-if.mjs` allow-list | Pass |
| 4 | Azure inventory for ACA jobs/environments | No live pilot resources |
| 5 | GitHub variable/environment inventory | Activation variable/environment absent |
| 6 | Enabled Provider what-if with synthetic credentials | Structural pass; no apply |

| Tool | Version |
|---|---|
| Azure CLI | 2.89.1 |
| Bicep CLI | 0.44.1 |
| Azure Developer CLI | 1.30.0 |

## Issues

### Enabled pilot cannot be proved safe yet

- **Severity:** Blocking
- **Source:** Supply chain and GitHub control-plane prerequisites
- **Evidence:** No published immutable Certigo runner image with verified
  digest, SBOM, signature and scan; no dedicated GitHub App IDs/private key.
  The enabled what-if used a disposable RSA key, synthetic IDs and the pinned
  public Node base image only to validate ARM schema and permissions.
- **Action:** Complete and review all prerequisites in
  `docs/runbooks/ACA_JOBS_PILOT.md`, then run the enabled Provider preflight.

### Local image smoke test unavailable

- **Severity:** Warning
- **Source:** Validation workstation
- **Evidence:** Docker CLI is installed but the Docker Desktop Linux engine is
  not running.
- **Action:** Build and smoke-test `linux/amd64` on a trusted builder before
  publishing. Do not infer image success from static tests.

### Recurrent VMSS outage

- **Severity:** High operational evidence
- **Source:** GitHub read-only inventory, 2026-09-04
- **Evidence:** Runners 27 and 28 were simultaneously offline; PR #366 and
  other runs remained queued from `03:15Z`.
- **Action:** Keep incident response separate. The ACA pilot must remain
  independent of VMSS compute and must not be represented as full-CI fallback.

## What-If Results

| Change type | Count |
|---|---:|
| Create | 3 |
| Modify | 0 |
| Delete | 0 |
| No Change | 0 |
| Ignore | 58 unrelated existing resources |

### Resources to create

| Resource type | Resource name |
|---|---|
| `Microsoft.OperationalInsights/workspaces` | `log-certigo-aca-pilot` |
| `Microsoft.App/managedEnvironments` | `cae-certigo-ci-aca-pilot` |
| `Microsoft.Insights/diagnosticSettings` | `certigo-aca-pilot-logs` |

No Container Apps Job is present in the disabled plan. The 58 ignored resources
are existing resources outside this incremental template; the strict validator
rejects any ignored resource whose name belongs to the pilot.

The enabled structural plan returned 4 Create, 58 unrelated Ignore and exactly
one `Microsoft.App/jobs/job-certigo-pr-aca`, with no Modify or Delete. It is not
an activation approval because its image and GitHub App inputs are synthetic.

## Recommendation

Do not deploy from this report. It proves that both conditional paths are
syntactically/provider-valid and that the bounded plans have no mutation or
deletion. Activation remains blocked until image supply-chain evidence, the
dedicated GitHub App, a Provider what-if with those real inputs and human
approval all exist.
