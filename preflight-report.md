# Azure Deployment Preflight Report

**Generated:** 2026-09-04T11:15:56Z  
**Status:** Fail - deployment blocked; safe reconciliation PR only

---

## Summary

| Property | Value |
| --- | --- |
| **Template files** | `infra/main.bicep`, `infra/ci-runner/network.bicep`, `infra/ci-runner/capacity.bicep`, `infra/modules/openai.bicep` |
| **Parameter files** | `infra/params/dev.bicepparam`, `infra/params/staging.bicepparam` plus ephemeral secure overlays |
| **Project type** | Standalone Bicep (`azure.yaml` absent) |
| **Deployment scopes** | Subscription and resource group |
| **Targets** | Subscription `MCAPS-Hybrid-REQ-150432-2026-gchambaud`, `rg-certigo-ci`, `rg-certigo-dev`, `rg-certigo-staging` |
| **Validation level** | `Provider`; no `ProviderNoRbac` fallback |

### Validation Results

| Check | Status | Details |
| --- | --- | --- |
| Bicep syntax | Pass | Root, dev/staging parameters, CI network/capacity and OpenAI compiled with Bicep 0.44.1 |
| Repository validation | Pass | Full `infra/validate.sh`, 105 infrastructure contract tests and complete CI runner validator |
| Permission check | Pass | Current principal has `Owner` at subscription scope |
| Bounded CI network what-if | Pass | Three tag-only modifications; subnet `NoChange`; no infrastructure create/delete and no PUT of IP/NAT/NSG/VNet |
| Bounded CI capacity what-if | Pass with review | One autoscale modification: add FinOps tags and remove only the CPU `Decrease` rule |
| Bounded OpenAI what-if | Pass for IaC scope; runtime blocked | Account tags only; existing role assignment `NoChange`; model reports provider-owned `currentCapacity` noise; Foundry private DNS path is incomplete |
| Full dev what-if | Fail for deployment | Provider validation succeeds with 50 broad modifications and no creates/deletes; unrelated baseline drift remains unsafe to apply wholesale |
| Full staging what-if | Fail | Template evaluation stops because the verified public-domain inputs required since #364 are not configured |

The preflight authorizes review of this PR, not an Azure deployment.

## Live Read-Only Evidence

- `rg-certigo-staging` exists with 35 resources. Subscription deployment
  `certigo-staging` succeeded on 2026-08-16 in Incremental mode.
- Staging Storage, Cosmos DB and Key Vault have public access disabled; Storage
  shared-key access and Cosmos local auth are disabled; Cosmos uses
  `Continuous7Days`; Key Vault uses RBAC and purge protection.
- The staging Function App is running and `/api/health/live` and
  `/api/health/ready` both return HTTP 200.
- `vmss-certigo-runner-zonal` is Flexible, `Standard_D2ads_v6`, zones 1/2,
  capacity 2. `vmss-certigo-pr-pilot-z1` is Flexible,
  `Standard_D2ads_v6`, zone 1, capacity 1.
- `f55d176e` and `bbf83c5c` are running. `be505fa1` remains deallocated and
  intentionally unclassified.
- GitHub reports one online trusted runner and one online busy PR runner.
- The live autoscale profile is 2/2/4 with CPU scale-out above 70 percent for
  10 minutes and CPU scale-in below 20 percent for 45 minutes.
- `certigo-openai` is an `AIServices` S0 account in `swedencentral`, with
  public access disabled, local auth disabled and a system identity. Its
  `gpt-5.4-mini` deployment is version `2026-03-17`, `GlobalStandard`,
  capacity 1. The existing Function App role assignment is
  `f2f408f8-6106-4435-980c-a4d178e67fd2`.
- Its private endpoint advertises `certigo-openai.services.ai.azure.com` at
  `10.60.0.76`, but has no private DNS zone group. The only OpenAI zone in
  `rg-certigo-dev` is `privatelink.openai.azure.com`, with a different
  `10.60.0.75` record; the required
  `privatelink.services.ai.azure.com` zone is absent.

## Tools Executed

| Tool | Version |
| --- | --- |
| Azure CLI | 2.89.1 |
| Bicep CLI | 0.44.1 |
| Azure Developer CLI | 1.30.0 (not used; no `azure.yaml`) |

Key commands:

```text
bicep build <template> --outfile <temporary-file>
bicep build-params infra/params/{dev,staging}.bicepparam --outfile <temporary-file>
az deployment group what-if ... --validation-level Provider
az deployment sub what-if ... --validation-level Provider
az role assignment list ... --include-inherited
```

No `az deployment create`, resource write, start, stop or delete command was
executed.

## Issues

### Error: staging public-domain contract is incomplete

- **Source:** subscription what-if / repository environment
- **Message:** `publicWebOrigin must be a canonical HTTPS origin on a
  non-placeholder domain controlled by Certigo.`
- **Evidence:** the `staging` GitHub Environment does not define
  `PUBLIC_WEB_ORIGIN`, `PUBLIC_DOMAIN_VERIFIED` or
  `APPLE_CIAM_DOMAIN_RECONFIGURED`. The required signing and Graph secret names
  are present.
- **Remediation:** establish and verify a Certigo-controlled domain, configure
  all three environment variables, regenerate the ephemeral secure parameters
  and rerun the Provider-level staging what-if. Do not substitute a guessed
  domain.

### Warning: full dev baseline has unrelated drift

The full dev what-if contains 50 `Modify` results, including provider-default
noise and writes to the dev VNet/peerings, private DNS links, private endpoints,
Cosmos containers, role assignments and Function App settings. It contains no
resource `Create` or `Delete`, but it is not a safe deployment plan for this
work package. The bounded OpenAI result below is the only reviewed dev scope.

### Warning: provider-owned OpenAI capacity field

The OpenAI what-if reports deletion of
`properties.currentCapacity=1` from the model deployment. This field is
returned by Azure but is not an input in the
`Microsoft.CognitiveServices/accounts/deployments@2024-10-01` Bicep schema.
The declared SKU capacity remains 1. Treat this as provider normalization and
review it again before any apply.

### Error: Foundry private DNS path is incomplete

- **Source:** private endpoint custom DNS configuration, private DNS inventory
  and public DNS resolution.
- **Message:** the configured runtime endpoint resolves through
  `certigo-openai.privatelink.services.ai.azure.com`, but the corresponding
  private DNS zone, A record, VNet link and private endpoint zone group are not
  established.
- **Impact:** keep `TUTOR_LLM_ENABLED=false`; a real keyless call from the
  Function App is not proven safe or routable.
- **Remediation:** adopt those four DNS surfaces in a separate, explicitly
  approved change with its own syntax validation and Provider what-if. Do not
  repurpose the existing classic `privatelink.openai.azure.com` zone.

### Note: local CI runner validator shell

Native Git Bash reached and passed the shell, health, lifecycle and
capacity-controller checks before reporting that `jq` is absent. The complete
validator then passed under the local WSL environment with `jq` 1.8.1 and
Node.js 22.22.1, including the toolchain, canary and image contract suites.

## What-If Results

### `infra/ci-runner/network.bicep`

| Change type | Count |
| --- | ---: |
| Modify | 3 |
| NoChange | 1 |
| Ignore | 58 |
| Create / Delete | 0 |

The three modifications target only `Microsoft.Resources/tags/default` on the
existing public IP, NAT Gateway and NSG. The existing runner subnet is
`NoChange`. The parent resources and VNet peerings are not emitted as PUTs.

### `infra/ci-runner/capacity.bicep`

| Change type | Count |
| --- | ---: |
| Modify | 1 |
| Ignore | 57 |
| Create / Delete | 0 |

The only modified resource is
`autoscale-vmss-certigo-runner-zonal`: mandatory FinOps tags are added and
`properties.profiles[0].rules[1]`, the CPU `Decrease` rule, is removed. The
2/2/4 capacity and CPU `Increase` rule remain. No VMSS or VM is emitted.

### `infra/modules/openai.bicep`

| Change type | Count |
| --- | ---: |
| Modify | 2 |
| NoChange | 1 |
| Ignore | 37 |
| Create / Delete | 0 |

- Account: add mandatory FinOps tags; private/keyless settings remain unchanged.
- Model deployment: provider-owned `currentCapacity` normalization only.
- Existing OpenAI User role assignment: `NoChange`.
- Existing Foundry project and private endpoint are references, not adoption
  targets. No DNS zone is claimed by this module because the matching Foundry
  zone is absent live.

### `infra/main.bicep` with `dev.bicepparam`

Provider validation succeeded with 50 `Modify` results and no
`Create`, `Delete` or `Unsupported` result. This broad baseline is diagnostic
only and must not be applied from this work package.

### `infra/main.bicep` with `staging.bicepparam`

Provider validation did not reach change calculation because the public-domain
contract failed during template evaluation. No staging resource mutation was
attempted.

## Recommendations

1. Review and merge only the repository reconciliation; do not apply any Azure
   plan from this PR.
2. Configure the verified staging public-domain contract, then rerun the exact
   secure Provider what-if from `docs/runbooks/AZURE_IAC_OPERATIONS.md`.
3. Adopt the Foundry private DNS path in a separate approved change before
   enabling `TUTOR_LLM_ENABLED` or attempting a live tutor call.
4. Triage the 50-item dev baseline in separately bounded work before any root
   deployment.
5. Apply the CI tag and autoscale changes only after explicit operator approval;
   keep the queue controller disabled and keep all VM/VMSS/VNet resources out of
   the deployment plan.
6. Keep R-03 outside this work package.

---

*Report generated by Azure Deployment Preflight Skill.*
