# FinOps minimal

## Perimeter and measured baseline

This guardrail set is deliberately independent from application deployment,
observability, RBAC, governance, and the runner controller. It reserves no
capacity and is not deployed by CI.

Actual cost, measured on 2026-09-11 through the Cost Management query API
(`ActualCost`, monthly granularity, grouped by `ResourceGroupName`) against
subscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc`:

| Scope | Resource group | Jul 2026 | Aug 2026 | Margin | Monthly budget |
| --- | --- | ---: | ---: | ---: | ---: |
| CI | `rg-certigo-ci` | 256.44 | 298.20 | ×1.26 | 375 |
| Staging | `rg-certigo-staging` | 20.02 | 55.87 | ×1.25 | 70 |
| Production | `rg-certigo-prod` | 18.73 | 41.11 | ×1.34 | 55 |
| Development | `rg-certigo-dev` | 15.16 | 42.84 | ×1.28 | 55 |
| Content | `rg-certigo-content` | 0.00 | 0.00 | ×1.54 | 25 |
| **Certigo total** | | **310.35** | **438.02** | | **580** |

**Each amount is `ceil_to_5(1.25 x August 2026 actual)`, and the margin is written
because a budget without a stated margin cannot be audited.** The 1.25 factor is not a
rounding: it is the threshold design. A normal month then lands at 80% of budget, which
is what lets `forecast100` mean "25% above a normal month" rather than "some level". The
effective margins differ from 1.25 only by the rounding to the nearest 5, except
`rg-certigo-content` at ×1.54: that scope had no August cost at all, so its baseline is
a September run rate of 16.23 USD/month and the rounding to 25 is proportionally larger
on a small number. Read its first alert as a calibration signal, not an overrun.


The subscription also carries `mcapsgovernance` (14.37 then 15.05) and a small
unassigned remainder, for a subscription total of 324.96 then 454.67. Those two
are outside the Certigo scopes and are covered only by the pre-existing
subscription-level `FDPOAzureBudget`.

`rg-certigo-identities` and `rg-certigo-web` exist but measured 0.00 in both
months, so they carry no budget. `rg-certigo-content` first showed cost in
September 2026; its budget is sized on that run rate, not on August.

> **These amounts are calibrated on August 2026, the last complete month before
> activation.** They are invalidated when a monthly review records an actual
> above budget for two consecutive months, or when a scope's resource
> composition changes. Re-baseline then — do not raise a budget merely to
> silence an alert.

CI is the dominant cost, and daily measurement on 2026-09-11 shows it is **not**
fixed. `rg-certigo-ci` ran at a 3.40 USD/day idle floor from 2026-08-22 to
2026-08-29, then rose to a 20-22 USD/day plateau between 2026-09-08 and
2026-09-10. Reproduce with a `Daily` granularity query filtered to that
resource group.

> **Cost data is provisional and is restated.** The same day, 2026-09-10, first
> returned 40.84 and later settled at 20.42 — the only revised day in that
> window, and a factor of two. Read the most recent days as estimates: the
> latest day is always partial because data lags 8-24 hours, and a recent day
> can still be revised after it looks complete. Re-read before escalating a
> number.

Broken down by service, the slope has two independent components, and only one
of them is driven by CI activity:

| Component | USD/day | Driven by |
| --- | ---: | --- |
| Network floor (2 NAT gateways 2.16, storage, VNet, DNS) | 3.40 | Nothing — bills 24/7 with the VMs deallocated |
| Standing VM compute | ~9.62 | Instance-hours, not jobs — see the unit-price caveat below |
| NAT data processing, disk transactions, bandwidth | 0 to 5.32 | Workflow runs |

The middle row is measured, not modelled: on 2026-09-05, 515 workflow runs cost
9.64 USD of compute; on 2026-09-06, **5** runs cost 9.62 USD. Cutting activity
by two orders of magnitude changed compute cost by 0.02 USD. Four
`Standard_D2ads_v6` instances stay provisioned because
`autoscale-vmss-certigo-runner-zonal` has `minimum = 2` and
`vmss-certigo-pr-pilot-z1` has no autoscale rule at all.

**That row is instance-hours, not continuous running.** Priced at the published rate,
those 9.62 USD are 69.7 VM-hours, so the fleet is already down about a quarter of the
day; the reducible part is therefore the *remaining* uptime, not the whole row. Do not
quote a 24/7 figure from it.


**Two consequences for anyone reading a cost spike here.** Reducing workflow
parallelism is close to a no-op: the VMs are already paid for, so additional
jobs are nearly free. And the reducible cost is the standing compute, which is
an architecture question — scheduled deallocation, or runners woken on a
`workflow_job` webhook — not a budget threshold. The VMs billed 0.00 from
2026-08-22 to 2026-08-29, so deallocation is compatible with this setup.

**Runner capacity is adequate in normal regime, and this is measured per regime rather
than on average.** Wait before a `certigo-pr` job found a runner, sampled by day:

| Day | Regime | Jobs | Never started | Median | p90 |
| --- | --- | ---: | ---: | ---: | ---: |
| 2026-09-06 | 5 workflow runs | 5 | 0% | 2 s | 99 s |
| 2026-09-09 | 887 workflow runs | 271 | 0% | 35 s | 201 s |
| 2026-09-11 | rebase burst | 181 | **41%** | 98 s | **1701 s** |

**A median computed only over jobs that started excludes the ones waiting longest**, so
it under-reports saturation by construction — which is why the "never started" column is
shown next to it and why an average across regimes is not reported. Read the two together
or neither.

The decisive comparison is 2026-09-09 against 2026-09-11: the busier day, at 887 runs,
started **every** job with a 35 s median, while a later day with fewer runs left 41%
unstarted and a p90 of 28 minutes. **Saturation here is caused by many runs concentrated
on one label in a short window, not by daily volume**, so it is an event to wait out
rather than a capacity floor to raise. An instantaneous "3 of 4 runners busy" reading
says nothing about either and must not be mistaken for starvation.

Billing follows provisioned capacity rather than occupancy, at a measured **0.1380 USD
per VM-hour** (`Standard_D2ads_v6`, West Europe, Linux, non-Spot, read from the public
retail price API), so extra instances are strictly additive, never neutral.

> **A price derived from consumption cannot then prove how long the machines ran.** An
> earlier revision of this document quoted 0.1002 USD/VM-hour, obtained by dividing one
> day's cost by an *assumed* 4 x 24 VM-hours — and then used that price to conclude the
> instances ran continuously. The conclusion was true by construction. Priced against the
> published rate instead, 2026-09-06 is **69.7 VM-hours, not 96**: about 17.4 hours per
> instance, so roughly a quarter of the day is already torn down. Busier days land near
> 93 VM-hours, close to continuous. **Take the unit price from the rate card, never from
> the quantity you are trying to measure.**

> **An idle `certigo-trusted` runner while `certigo-pr` has a backlog is not waste.**
> The two pools are a trust boundary: `certigo-trusted` holds deployment credentials,
> `certigo-pr` executes unreviewed branch code. Merging them, or letting the trusted
> pool serve pull-request jobs, would place arbitrary PR code on a machine holding Azure
> credentials. **The idle trusted runner is the price of that separation — do not
> reclaim it.** This is the kind of apparently absurd cost a reader in a hurry deletes.

One latent defect, recorded rather than fixed here: `post-merge-cosmos-account-deletion.yml`
targets the `certigo-cosmos-emulator` label, for which no runner is registered. It is not
a required check and blocks no pull request, but that post-merge cleanup never runs.

### Why the CI runners cannot scale, measured 2026-09-11

> Invalidated the day `rg-certigo-ci` loses its `CanNotDelete` lock, **or** the day
> `vmss-certigo-pr-pilot-z1` stops booting a stock image. Either change alone
> invalidates this whole subsection; re-read it rather than amend it.

> ⚠️ **Corrected by measurement on 2026-09-23 — read this before the text below.** Three
> statements of this 2026-09-11 subsection are contradicted by the Activity Log and by ARM,
> and the measured facts are written once in `docs/CI_RUNNER_RESILIENCE.md`, section
> « Cause racine des instances PR mortes — mesurée le 2026-09-23 »:
> 1. `pr-pilot` does not boot "with no cloud-init": `pilot.bicep` ships the bootstrap as
>    `customData`, which is write-only (`az vmss show` renders `False`). New instances carry
>    no runner because registration is manual by design, and because every instance created
>    while the NSG rule `deny-imds-outbound` was active failed OS provisioning.
> 2. The scale-in rule was not harmless: a scale-in under the lock is refused per instance
>    (`ScopeLocked`) and leaves the targeted instance in `provisioningState: Failed`. That is
>    how `bbf83c5c`, `a14700a3` and `d8d42366` died on 2026-09-11/12. The rule was removed from
>    the live autoscale on 2026-09-23 at 18:01Z.
> 3. The recovery Logic App no longer names any instance: since 2026-09-23 it enumerates the
>    members of both scale sets on every run.
> Disk figures below are also stale: on 2026-09-23 all 13 OS disks, including the seven of
> the retired PR instances, are 128 GiB `Standard_LRS`, not `Premium_LRS` (`az disk list`).
> The templates still request `Premium_LRS`. Azure Resource Graph change history shows that
> the MCAPS governance automation (appid `a1a9c5b6-7a4f-4288-89ab-6805873f65d1`) downgraded
> the six PR OS disks created on 2026-09-14 between 00:56:04 and 01:06:09Z on 2026-09-15.

Two independent mechanisms, each sufficient on its own to prevent scaling:

1. **Adding capacity to `certigo-pr` cannot add a runner.**
   `vmss-certigo-pr-pilot-z1` boots the stock `Canonical / ubuntu-24_04-lts / server`
   image with no extension and no cloud-init, so a new instance comes up as plain Ubuntu
   with no runner agent. `vmss-certigo-runner-zonal`, which does register, boots the
   specialized gallery image `certigoRunnerNvmeSpecialized/1.0.0`. Measured directly:
   three instances were added to `pr-pilot` and **zero** new runners appeared. The two
   `certigo-pr` runners are manually registered, as the resource-group lock note itself
   records. **Fixing the image is the prerequisite for any autoscale rule on this pool.**
2. **Scaling in is refused by a resource lock.** `rg-certigo-ci` carries a
   `CanNotDelete` lock named `certigo-ci-cannot-delete`, which protects the shared
   private DNS zones and the manually restored runner registrations. Reducing scale-set
   capacity requires deleting instances, so it returns `ScopeLocked`. **The scale-in rule
   on `autoscale-vmss-certigo-runner-zonal` (`Percentage CPU < 20` → −1) therefore cannot
   execute.** It is a guardrail that looks active and can never fire — which is why the
   instances run continuously, and the deeper cause of the standing compute cost above.

**The lever that does work is deallocation, not deletion.** Both scale sets run in
`Flexible` orchestration mode, so each instance is an ordinary virtual machine and
`az vm deallocate` succeeds under the lock, stopping compute billing while leaving the
disk. Any scale-to-zero design here must deallocate rather than scale in, or must
explicitly lift the lock first — which the lock's own note requires to be a deliberate,
stated act.

**A nightly stop-and-restart already exists, and a scale-to-zero would extend it rather
than invent it.** The `logic-certigo-ci-runner-recovery` Logic App is enabled, triggers
daily at 01:30 on `Daily_after_the_governance_teardown_window`, issues a `start` against
each runner virtual machine and then verifies its power state. It has succeeded every day
since 2026-09-05. **It names the four instances literally in its definition**, so an
instance that is ever replaced is silently no longer restarted — and, conversely, the
instances left deallocated on 2026-09-11 stay down precisely because they are absent from
that list. Widening the gap between the teardown and this restart is the cheapest
available reduction of the standing compute cost, and it needs no new mechanism.

**Deallocated instances keep a Premium OS disk, which bills in full.** The two serving
instances use `Standard_LRS`; the instances created during the 2026-09-11 scaling tests
use **128 GiB `Premium_LRS`**, left in `Reserved` state. At the published P10 LRS rate of
**21.68 USD/month**, those three residual disks cost **65.04 USD/month** — more than a
fifth of the whole fleet's compute, for machines that never served a job. A stopped
instance is not a free instance. They cannot be deleted while the lock stands, so
removing them is a deliberate act that must lift the lock first.

## Guardrails

`infra/finops/main.bicep` is an opt-in subscription deployment. Its default
`enableBudgets = false` creates no budget, and three assertions in
`infra/tests/finops-guardrails.test.mjs` keep that default. Enabling it is a
command-line override, never a repository change.

Budgets notify only; they do not stop resources or consumption. Cost data can
lag 8-24 hours and Azure evaluates budgets daily.

Each budget carries three notifications, and each threshold is chosen against a
mechanism rather than a convention:

| Notification | Type | Threshold | What constrains it |
| --- | --- | ---: | --- |
| `forecast100` | Forecasted | 100% | Amounts are 1.25x the last complete normal month, so a normal month projects to 80% of budget. This fires only when the month's burn rate runs 25% above that month — an acceleration, not a level. |
| `forecast200` | Forecasted | 200% | Separates a drift from a burn. The 2026-09-10 CI rate projects to about 327% of the CI budget, so this tier discriminates a runaway from a 25-50% overshoot. |
| `actual100` | Actual | 100% | Ground truth. Fires only once the overrun has really happened, and cannot be produced by a forecast artefact. |

**No Actual threshold below 100% is allowed**, and the test asserts it. With
amounts at 1.25x a normal month, an `Actual 80%` alert fires in every normal
month by construction and an `Actual 50%` alert fires around day 19 of every
normal month. Both are noise by construction, and a noisy alert is muted, which
returns the whole mechanism to the state it was meant to leave.

The criterion discriminates in both directions, which is what makes it a
criterion: a normal +16% month (the measured July-to-August CI variation)
projects to 92% of budget and stays silent, while the measured September rate
projects to 135-224% and fires.

### Deploying the budgets

The recipient is never committed, never written to a repository file, and never
passed literally on a command line. Inject it from the environment:

```powershell
if ([string]::IsNullOrWhiteSpace($env:ALERT_EMAIL)) {
  throw 'ALERT_EMAIL must be set before deploying budgets.'
}

az deployment sub what-if `
  --name certigo-finops-activation-preview `
  --location westeurope `
  --subscription <subscription-id> `
  --template-file infra/finops/main.bicep `
  --parameters infra/params/finops.bicepparam `
  --parameters enableBudgets=true alertEmail=$env:ALERT_EMAIL
```

Review the scopes, amounts, thresholds, and dates, then replace `what-if` with
`create` and use a dated deployment name. `alertEmail` is a `securestring`, so
the value appears in neither the what-if output nor the deployment history.

### Verifying the budgets exist

**A deployment exit code is not evidence.** An Azure Policy with a `modify`
effect can rewrite a submitted value and still return HTTP 200 and exit 0, which
makes the deployment an instrument that attests an operation that did not
happen. Always re-read the deployed state through an independent request:

```powershell
az rest --method get --output json `
  --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/rg-certigo-ci/providers/Microsoft.Consumption/budgets/budget-certigo-ci-monthly?api-version=2023-11-01"
```

Compare `properties.amount`, every `properties.notifications.*` threshold and
`thresholdType`, and confirm `contactEmails` holds exactly one entry. Compare
that entry by hash rather than printing it.

Pair the read with a negative witness through the same invocation and options —
request a budget name that does not exist, and list budgets on
`rg-certigo-web`, which is expected to have none. **An absence only informs
when the instrument has been shown able to return a presence.**

`currentSpend` and `forecastSpend` are populated by Cost Management on its own
cycle and are empty on a freshly created budget. Re-read them within 48 hours:
if `currentSpend` is still zero while a Cost Management query reports non-zero
cost for that scope, the budget exists but is not evaluating, and the alert is
not connected.

### Removing the budgets

```powershell
az consumption budget delete --budget-name budget-certigo-ci-monthly `
  --resource-group rg-certigo-ci --subscription <subscription-id>
```

Repeat per scope, then re-read to confirm the deletion, for the same reason the
creation is re-read. Deleting a budget deletes no cost data and stops no
resource.

### Why this is not deployed by a workflow

It must not be, and the repository makes it impossible.

1. **A new privileged workflow is refused.** Any workflow that authenticates to
   Azure needs `azure/login@`, `secrets.`, or `id-token: write`, each of which
   makes it privileged under `privilegedWorkflow` in
   `.github/scripts/backend-deploy-workflow-policy.mjs`. That file then rejects
   any new or changed privileged workflow outside `cd-backend.yml` with
   `changed or new privileged capability is forbidden outside cd-backend.yml`.
2. **Folding it into `cd-backend.yml` would leak the recipient.** It would have
   to become a CI secret and transit CI logs and deployment history — exactly
   the exposure the `securestring` parameter exists to prevent.
3. **Budget amounts are a calibration decision, not a per-commit artefact.**
   Re-asserting them on every backend deployment would silently revert any
   deliberate adjustment.

The cost of deploying manually is that it can be forgotten. That is bounded by
the read-back command above, which answers "do the budgets exist" in one
request, and belongs to the monthly cost-SLO review below.

### Arming `enableBudgets` in the repository still protects nothing — but five budgets are deployed

> **Five resource-group budgets exist in Azure and were verified on 2026-09-11** by
> re-reading each one through an independent REST request: amount, `timeGrain`,
> category, all three thresholds and their `thresholdType`, and a single contact
> entry compared by hash. Zero deviations. Two negative witnesses, through the same
> invocation and options, confirmed the reader can return an absence. **This section
> is about the repository flag, not about whether Certigo is protected — it is.**

> Volatile facts, dated and bounded. Measured **2026-09-11**. Each claim below carries
> its own condition. **Any one of them changing invalidates the section as a whole**,
> which must then be re-read in full rather than amended in place — a section that can
> half-expire is a section whose remaining half is trusted for the wrong reason.

Three measurements, to be set against any proposal to flip `enableBudgets = true` in a
committed parameter file:

1. **No workflow deploys this template.** `git grep -- "--template-file" .github/workflows`
   returns only `infra/main.bicep` (`cd-backend.yml`) and `infra/content/main.bicep`
   (`content-infra-apply.yml`, `content-infra-what-if.yml`). The single `finops`
   occurrence in the workflows is `node --test infra/tests/finops-guardrails.test.mjs`
   (`ci-infra.yml`). Flipping the parameter in the repository therefore creates **no
   budget in Azure**; it creates only the belief that a budget exists.
   *Still true on 2026-09-11, and deliberately so — see "Why this is not deployed by a
   workflow".*
2. **Three assertions lock it to `false`** in `infra/tests/finops-guardrails.test.mjs`
   (template default, `.bicepparam` value, and the literal `param enableBudgets = false`
   pattern). Flipping it turns `ci-infra` red while protecting nothing more.
   *Still true on 2026-09-11; the deployment used a command-line override and left all
   three assertions untouched.*
3. **A recipient is established out-of-band, and is still not committable.** `alertEmail`
   remains a `securestring` defaulting to the empty string, and this document still
   forbids committing a personal address. The deployed budgets carry a reachable contact
   that was injected at deployment time and exists in no repository file.
   *Changed on 2026-09-11: a recipient now exists. What has not changed is that it must
   never be committed.*

**The gesture that actually protects money is therefore not a pull request.** It is an
out-of-band `az deployment sub create` with `ALERT_EMAIL` injected, decided by a human
owner, and verified by re-reading budget state rather than by trusting the return code —
an Azure Policy with a `modify` effect can return success having rewritten the values.
**That gesture was performed on 2026-09-11**, and the read-back above is its evidence.


## Cost-allocation tag contract

Every resource group and taggable resource in the four scopes must expose:

| Tag | Contract |
| --- | --- |
| `owner` | Non-empty team or service owner; no personal address |
| `product` | `Certigo` |
| `env` | `ci`, `dev`, `staging`, or `prod`, matching the scope |
| `managedBy` | `bicep` |
| `costCenter` | Non-empty allocation identifier |

Azure resource-group tags are not inherited automatically by child resources.
The application and historical CI runner templates now merge caller-provided
tags with the five mandatory values, with the canonical contract taking
precedence on collisions. Shared hub resources keep `env=ci` because they live
in `rg-certigo-ci`, including when a staging or production composition references
them. The read-only verifier checks both the group and resources:

```powershell
node infra/finops/verify-tags.mjs --subscription <subscription-id>
```

The command uses only `az group show` and `az resource list`; it does not set the
active subscription and performs no write. Resource-group tags remain an
admin/bootstrap concern because the steady-state application deployment treats
those groups as existing and has no resource-group write permission.

The verifier reports violations today: measured on 2026-09-11, `rg-certigo-ci`
carries no tags at all, and `rg-certigo-content` carries no `env` tag. Tagging
those groups is the admin/bootstrap task above, not a deployment change. The
budget scopes are deliberately not driven by this contract —
`infra/finops/scopes.json` lists the four application environments and is pinned
by `infra/tests/azure-tag-contract.test.mjs` to the `env` allowed values of
`infra/main.bicep`, so the content budget is declared directly in
`infra/finops/main.bicep` and `infra/params/finops.bicepparam` instead.

## Retention without risky deletion

The existing storage lifecycle remains unchanged:

- function deployment packages under `app-package/deployments/` expire after
  30 days;
- release bundles and their versions under `app-package/releases/` expire after
  90 days;
- lesson assets, arbitrary blob prefixes, and Cosmos DB data have no FinOps
  deletion rule.

The dedicated test locks those prefixes and periods. This PR does not reduce
Application Insights, Key Vault, backup, or recovery retention.

## Monthly cost-SLO review

Complete this table during the first five business days of each month. Use Cost
Management for amortized and actual cost, then correlate with the existing
Application Insights readiness web test and `AppRequests` telemetry. Do not
change SLO targets or alert rules from this review; route such changes to the
observability owner.

| Scope | Actual cost | Budget | Delta vs prior month | Availability/readiness | 5xx rate | p95 duration | Decision/owner |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| CI |  | 375 |  | N/A | N/A | N/A |  |
| Staging |  | 70 |  |  |  |  |  |
| Production |  | 55 |  |  |  |  |  |
| Development |  | 55 |  |  |  |  |  |
| Content |  | 25 |  | N/A | N/A | N/A |  |

Review rules:

1. Explain any 20% month-over-month increase or any budget alert.
2. Confirm the five budgets still exist, using the read-back command above. A
   budget that was deleted or rewritten reports nothing, exactly like a budget
   that never fired.
3. Treat CI as fixed only while daily cost stays near its idle floor; the
   2026-09 measurement shows it does not always. Do not reserve or upscale from
   cost alone.
4. Compare cost changes with availability, 5xx rate, and p95 latency before
   proposing a SKU or retention change.
5. Record an owner and due date for approved actions; otherwise record "observe".
6. Re-baseline only after two complete months or an approved architecture
   change.

A separate workbook is not deployed here: it would duplicate the observability
surface and a cost export would add storage and operational ownership. The table
is the compatible zero-resource monthly report. If observability later publishes
a workbook, link it here rather than creating a second one.

## Validation and marginal cost

```powershell
bicep build infra/finops/main.bicep --stdout
bicep build-params infra/params/finops.bicepparam --stdout
node --test infra/tests/finops-guardrails.test.mjs
checkov --directory infra --framework bicep --compact --quiet `
  --config-file .checkov.yaml
```

Estimated direct marginal Azure cost is **USD 0/month**: Cost Management budgets,
the tag audit, tests, and documentation add no metered resource. No workbook,
scheduled export, storage account, telemetry ingestion, reservation, or SKU
change is introduced.

References:

- [Create and manage Azure budgets](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Bicep schema for `Microsoft.Consumption/budgets`](https://learn.microsoft.com/azure/templates/microsoft.consumption/2023-11-01/budgets)
- [Azure resource tags and inheritance](https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources)
