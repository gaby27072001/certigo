# Isolated backend runner design

> **Status: UNKNOWN / NO-GO.** This directory is a disabled, code-only design.
> It is not evidence that the pools, images, GitHub environments, workflows, or
> physical controls exist. Do not deploy or enable capacity from this change.

This design separates trusted `main` builds from Azure deployment:

| Boundary | Builder | Deployer |
| --- | --- | --- |
| Exact label | `certigo-backend-builder` | `certigo-backend-deployer` |
| Workload | Build trusted `main` source | Verify and deploy an artifact |
| Azure identity | Forbidden | GitHub OIDC only after artifact verification |
| Source checkout | Allowed | Forbidden |
| Build tools | .NET SDK 8.0.424, Node 20.20.2 | None |
| Persistent project cache or Docker | Forbidden | Forbidden |
| Runtime host identity / IMDS | No managed identity; OS and NSG deny IMDS | No managed identity; OS and NSG deny IMDS |
| Runtime lifecycle | Fresh one-job instance, then delete or reimage | Fresh one-job instance, then delete or reimage |

Aliases, suffixes, default labels, `certigo-trusted` fallback, and dual-label
registration are forbidden. Runner IDs 24 through 27 and their historical
hosts are denied as candidates for these pools.

## Disabled resource model

`main.bicep` models two subscription-level runtime resource groups. Each group
contains one Flexible VMSS and a dedicated VNet, subnet, NSG, NAT Gateway, and
NAT public IP. Builder and deployer use different names, CIDRs, and zones.
There is no VNet peering or application-private route. VMSS model capacity is
zero and the controller maximum is one instance per class.

Every Azure resource is conditional on all reviewed gates. The checked-in
state deliberately prevents evaluation to true:

- every Bicep entry point defaults `deploymentEnabled` to `false`;
- every mutation authorization and activation approval is `false`;
- Image Builder auto-run is disabled;
- controller `enabled` and both backend `classEnabled` values are `false`;
- backend capacity is zero in `idle`, `normal`, and `boost`.

The runtime VMSS omits the `identity` property and sets
`allowExtensionOperations=false`; reviewed cloud-init is its only runtime
configuration path. The user-assigned identity in `image-build.bicep` belongs
only to Azure VM Image Builder and is never attached to either runtime VMSS.

## Locked images

`backend-image-build-contract.json` defines a backend-only reproducible input
set instead of changing the general canary contract, which intentionally
remains `reproducibleInputsReady=false`.

The image inputs are pinned by immutable version and digest:

- Ubuntu Server `24.04.202608070`;
- GitHub Actions runner `2.336.0`;
- builder-only Node.js `20.20.2` and .NET SDK `8.0.424`;
- deployer-only GitHub CLI `2.96.0`;
- all embedded customization, validation, registration, cleanup, hook, and
  artifact-verification scripts.

Image creation performs no APT or project restore. Backend dependency restore
belongs only to a builder job and must use the eight committed
`packages.lock.json` files with `dotnet restore --locked-mode`. The deployer
contains no compiler, project cache, Azure CLI, Docker, or source tree.

## One-job lifecycle contract

The registration script accepts a short-lived token only on standard input and
requires positive controller generation, lease generation, and state revision
values. It registers with:

```text
--ephemeral --no-default-labels --disableupdate --labels <one exact label>
```

The job hooks refuse a second job and isolate temporary NuGet, npm, and .NET
state. Runner executables and the embedded deployer verifier remain root-owned;
only `_work`, `_diag`, and the per-job root are service-user writable. A
persistent, root-owned registration-consumed stamp prevents any second
registration after reboot. `ExecStopPost` first persists retirement identity,
kills service-user processes, removes runner
credentials, workspace, project caches, Docker/containerd state, and runtime
state, then powers off the VM even when cleanup fails. The declarative
controller emits `create-fresh` for backend scale-out and `delete-retired` for
backend scale-in. It remains read-only; no mutable executor is introduced here.
A stopped backend instance must never be restarted or relabeled.

## Artifact-before-OIDC contract

The builder may emit only the deployment package, CycloneDX SBOM, manifest,
and SLSA provenance. The deployer image carries a root-owned verifier that:

1. validates safe relative paths, sizes, and SHA-256 digests;
2. invokes `gh attestation verify` for the canonical manifest with exact repository,
   signer workflow, signer commit, source ref, source commit, and predicate
   type constraints;
3. requires a certificate-backed result with a verified timestamp and the
   manifest subject digest;
4. uses that signed manifest to validate the package and SBOM bindings; and
5. atomically creates a root-consumable verification marker.

A future protected-environment step may request Azure OIDC only after this
marker is checked. This change does not modify `cd-backend.yml`, permissions,
environments, secrets, rulesets, or runner registrations, so artifact flow
integration remains unapproved.

## Generic interfaces

The reusable modules are:

- `../modules/locked-runner-image.bicep`;
- `../modules/isolated-ephemeral-pool.bicep`;
- `../modules/isolated-runner-interface.json`.

They accept one immutable label and one workload-owned profile. A future,
separate content-runner change can supply its own images, networks, labels, and
activation contract without copying these modules. No `certigo-pr-ci` or
`certigo-publisher` pool is declared by this backend change. The recorded
content contract hash is a session-local design compatibility input, not an
attestation or approval.

The generic interface also reserves
`../modules/legacy-trusted-bootstrap-contract.json` for a future one-time
`certigo-trusted` bootstrap. Its complete runtime profile matches the generic
module input but remains `deploymentEnabled=false`, `activationReady=false`,
capacity zero, without an attested image ID, host identity, VM extensions,
peering, application route, secret, OIDC, Azure operation, or deployment
binding. It uses a dedicated admission controller and must never bind to the
existing four-class capacity controller or either backend wrapper.

The queue allowlist is fail-closed on repository `gchambaud_microsoft/Certigo`,
PR `#356`, immutable head
`447a18de80bedba494f8a94c2a8f05e2af29f7f9`, and only these workflow/job
pairs: `ci-project-state.yml/validate`, `codeql.yml/security-gate`, and
`security-gate.yml/security-gate`. PR `#354` is recorded only as the prior
queued context and is not admitted by this bootstrap contract. Any other
repository, PR, SHA, workflow, or job must destroy the fresh instance without
registration. Each admitted runner is one-job `--ephemeral` and must be
destroyed immediately afterward; all remaining bootstrap capacity must then be
destroyed.

Because the legacy label is intentionally shared with historical routing, the
future admission gate must also prove temporal exclusivity: no other matching
`Linux/X64/certigo-trusted` runner online, no non-allowlisted trusted job
queued, all other trusted workflows disabled or provably inert, and the queue
snapshot rechecked under an admission lease immediately before registration.
Any drift destroys the instance without registering it.

This change neither instantiates nor routes the profile. Immutable queue,
image, VMSS/VM/network, identity/IMDS, fresh-host/disk, one-job, and deletion
evidence plus independent approval are still missing, so the bootstrap is also
**UNKNOWN / NO-GO**.

## Offline validation for this change

These commands compile and inspect local files only:

```bash
BICEP_BIN=bicep bash infra/validate.sh
BICEP_CLI=bicep node --test \
  infra/ci-runner/backend/backend-runner.test.mjs \
  infra/ci-runner/capacity-controller.test.mjs \
  infra/ci-runner/evaluate-lifecycle.test.mjs
bash infra/ci-runner/validate.sh
```

They must not be replaced by an Azure validation, deployment, runner API call,
or live inventory query for this change.

## Future what-if procedure (not executed here)

A future operator may run what-if only after a separate change records all
design/security approvals, immutable image evidence, explicit mutation
authorization, subscription/location confirmation, quota review, and
independent approval. The review must use exact image version IDs and a
break-glass public key:

```bash
az deployment group what-if \
  --resource-group <DEDICATED_IMAGE_BUILD_RG> \
  --template-file infra/ci-runner/backend/image-build.bicep \
  --parameters deploymentEnabled=true \
               imageBuilderIdentityResourceId=<DEDICATED_AIB_IDENTITY_ID> \
               stagingResourceGroupId=<DEDICATED_AIB_STAGING_RG_ID> \
               location=<REGION>

az deployment sub what-if \
  --location <DEPLOYMENT_RECORD_REGION> \
  --template-file infra/ci-runner/backend/main.bicep \
  --parameters deploymentEnabled=true \
               location=<REGION> \
               builderGalleryImageVersionId=<EXACT_BUILDER_VERSION_ID> \
               deployerGalleryImageVersionId=<EXACT_DEPLOYER_VERSION_ID> \
               adminSshPublicKey=@<PUBLIC_KEY_FILE>
```

The image what-if may create only the dedicated gallery, two image definitions,
and two disabled image templates. The runtime what-if may create only the two
new runtime resource groups and their distinct resources. Any existing runner
host, peering, application route, managed identity, nonzero capacity,
unexpected resource, delete, or replacement is a blocker.

## Physical attestation acceptance

`backend-physical-attestation.schema.json` is the versioned contract for a
future immutable evidence record. Approval requires:

- repository commit SHA plus exact builder/deployer image version, VMSS, and VM
  resource IDs;
- all physical, identity, IMDS, routing, label, one-job, cleanup, and
  artifact-before-OIDC controls observed as true;
- exactly 20 cold and 20 warm samples for each pool (80 samples total);
- nearest-rank P50 and P95, recomputed from raw samples, for
  provisioning-to-online, queue-to-start, cleanup-to-delete, and replacement
  readiness;
- evidence file media types and SHA-256 digests; and
- approval by a reviewer independent from the implementer and bound to the
  same repository commit.

`validate-physical-attestation.mjs` is the fail-closed activation validator. It
accepts no network input: evidence paths are resolved relative to the
attestation file, regular non-symlink files are hashed locally, every sample is
bound to the expected image/VMSS IDs, VM IDs must be unique across all one-job
runs, and all nearest-rank percentiles are recomputed. A future operator must
provide every immutable expectation explicitly:

```bash
node infra/ci-runner/backend/validate-physical-attestation.mjs \
  --attestation <IMMUTABLE_ATTESTATION_JSON> \
  --collector-public-key <ALLOWLISTED_COLLECTOR_ED25519_PUBLIC_KEY> \
  --collector-signature <COLLECTOR_DETACHED_SIGNATURE> \
  --reviewer-public-key <ALLOWLISTED_REVIEWER_ED25519_PUBLIC_KEY> \
  --reviewer-signature <REVIEWER_DETACHED_SIGNATURE> \
  --expected-commit <REPOSITORY_COMMIT_SHA> \
  --expected-collector-id <COLLECTOR_ID> \
  --expected-reviewer-id <INDEPENDENT_REVIEWER_ID> \
  --expected-collector-key-sha256 <COLLECTOR_SPKI_SHA256> \
  --expected-reviewer-key-sha256 <REVIEWER_SPKI_SHA256> \
  --expected-builder-image-version-resource-id <BUILDER_IMAGE_VERSION_ID> \
  --expected-deployer-image-version-resource-id <DEPLOYER_IMAGE_VERSION_ID> \
  --expected-builder-vmss-resource-id <BUILDER_VMSS_RESOURCE_ID> \
  --expected-deployer-vmss-resource-id <DEPLOYER_VMSS_RESOURCE_ID>
```

The two Ed25519 keys must be distinct and pre-allowlisted outside the evidence
bundle. Their detached signatures authenticate the exact attestation bytes,
which bind five required evidence classes by digest. The validator also parses
the signed Azure inventory evidence and cross-checks all VM, image, VMSS, disk,
host-evidence, service-user, network, IMDS, identity, route, and peering claims.

Missing, inconsistent, mutable, or unapproved evidence produces `no-go`.
Until a distinct immutable record satisfies the contract, activation remains
UNKNOWN / NO-GO.
