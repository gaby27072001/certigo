# FinOps minimal

## Perimeter and current baseline

This guardrail set is deliberately independent from application deployment,
observability, RBAC, governance, and the runner controller. It creates no live
resource from CI and reserves no capacity.

| Scope | Resource group | 30-day baseline (USD) | Monthly budget (USD) |
| --- | --- | ---: | ---: |
| CI | `rg-certigo-ci` | 242.06 | 275 |
| Staging | `rg-certigo-staging` | 50.19 | 60 |
| Production | `rg-certigo-prod` | 24.48 | 30 |
| Development | `rg-certigo-dev` | 21.30 | 30 |

CI is the dominant, mostly fixed cost. Functions and Cosmos DB currently show
low usage, so this change does not recommend reservations, larger SKUs, or
provisioned throughput without measured utilization.

## Guardrails

`infra/finops/main.bicep` is an opt-in subscription deployment. Its default
`enableBudgets = false` creates no budget. When explicitly enabled, it creates
one monthly resource-group budget per scope with actual-cost notifications at
50%, 80%, and 100%. Budgets notify only; they do not stop resources or
consumption. Cost data can lag by 8-24 hours and Azure evaluates budgets daily.

No personal address is committed. A future approved deployment must inject the
existing `ALERT_EMAIL` value. The repository-default preview does not need that
value because all budget modules remain disabled:

```powershell
az deployment sub what-if `
  --name certigo-finops-default-preview `
  --location westeurope `
  --template-file infra/finops/main.bicep `
  --parameters infra/params/finops.bicepparam
```

The expected result is `No changes`. Enabling budgets is a separate, future
activation preview:

```powershell
if ([string]::IsNullOrWhiteSpace($env:ALERT_EMAIL)) {
  throw 'ALERT_EMAIL must be set before previewing enabled budgets.'
}

az deployment sub what-if `
  --name certigo-finops-preview `
  --location westeurope `
  --template-file infra/finops/main.bicep `
  --parameters infra/params/finops.bicepparam `
  --parameters enableBudgets=true alertEmail=$env:ALERT_EMAIL
```

This is a preview command, not an authorization to deploy. Review the
resource-group scopes, billing currency, budget start date, end date, and all
four amounts before any later `create` operation. Budget creation requires an
appropriately scoped Cost Management role; this change adds no role assignment.

### Arming `enableBudgets` inside the repository protects nothing

> Volatile fact, dated and bounded. Measured **2026-09-11** on `156c3117`.
> Invalidated the day a workflow passes `--template-file infra/finops/main.bicep`,
> or the day a non-personal alert recipient is established.

Three concurring measurements, to be set against any proposal to flip
`enableBudgets = true` in a committed parameter file:

1. **No workflow deploys this template.** `git grep -- "--template-file" .github/workflows`
   returns only `infra/main.bicep` (`cd-backend.yml`) and `infra/content/main.bicep`
   (`content-infra-apply.yml`, `content-infra-what-if.yml`). The single `finops`
   occurrence in the workflows is `node --test infra/tests/finops-guardrails.test.mjs`
   (`ci-infra.yml`). Flipping the parameter in the repository therefore creates **no
   budget in Azure**; it creates only the belief that a budget exists.
2. **Three assertions lock it to `false`** in `infra/tests/finops-guardrails.test.mjs`
   (template default, `.bicepparam` value, and the literal `param enableBudgets = false`
   pattern). Flipping it turns `ci-infra` red while protecting nothing more.
3. **No committable recipient exists.** `alertEmail` is a `securestring` defaulting to
   the empty string, and this document forbids committing a personal address. Budgets
   armed without a reachable contact notify into the void — the repository's dominant
   failure mode, not a guardrail.

**The gesture that actually protects money is therefore not a pull request.** It is an
out-of-band `az deployment sub create` with `ALERT_EMAIL` injected, decided by a human
owner, and verified by re-reading budget state rather than by trusting the return code —
an Azure Policy with a `modify` effect can return success having rewritten the values.


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
| CI |  | 275 |  | N/A | N/A | N/A |  |
| Staging |  | 60 |  |  |  |  |  |
| Production |  | 30 |  |  |  |  |  |
| Development |  | 30 |  |  |  |  |  |

Review rules:

1. Explain any 20% month-over-month increase or any 80%/100% budget alert.
2. Treat CI as fixed until runner utilization demonstrates an actionable idle
   window; do not reserve or upscale from cost alone.
3. Compare cost changes with availability, 5xx rate, and p95 latency before
   proposing a SKU or retention change.
4. Record an owner and due date for approved actions; otherwise record "observe".
5. Re-baseline only after two complete months or an approved architecture
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
