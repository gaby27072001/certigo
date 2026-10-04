# Promotion evidence tools

Operator-run Python 3.12 standard-library tooling. Importing modules performs no I/O.
No dependency installation, workflow change, direct deployment, automatic rollback,
OTP interaction, or authentication flow is implemented.

**This is not an authorization service.** Obtain external approval and keep a single
private evidence/receipt directory. Approval files record that decision; they are
not cryptographic signatures. Historic approvals never authorize a new promotion.
Do not publish private configuration, Azure JSON, contact details, or operational
decisions in this repository.

## Supported scope and deliberate limitations

| Supported | Not inferred |
|---|---|
| Full-payload subscription ARM what-if, inline Incremental nested templates | ARM expression evaluation, historical equivalence, fake-secret equivalence, or automatic metadata/Ignore exemptions |
| Exact resource/type/path/typed-before/typed-after decisions and fresh GET | Wildcard or resource-type-wide approvals |
| Complete paginated GET snapshots including ETags, hashes, informational comparison | Remediation or rollback from infrastructure drift |
| Main-push CD SHA and unique logged package digest; executed jobs and steps | Skipped jobs proving delivery; downloaded/mounted runtime ZIP bytes |
| Explicit `promote-backend` dispatch and separately approved code rollback | Direct Azure write, automatic rollback, blind POST retries |
| Exact rule properties, routing, Enabled + Verified receivers, health probes | Email delivery, real-user marker execution, application SHA health schema |
| Independent runtime-status observations | BuildSuccessful or healthy HTTP overriding RuntimeFailed |
| Original one-hour window, ingestion grace and persisted coverage gaps | Retrospective collection restoring historic live rollback coverage |

No historical CIAM/GetAccountDeletion exception or marker-specific probe is ported.
No legitimate user request is generated to exercise a marker. Health checks record
HTTP status and response hash, not application identity. A future build-identity
schema requires a separately reviewed verifier.

The tool does not download retained release artifacts or the mounted runtime ZIP.
`runtimeZipBytesVerified` is always false. Local ARM input hashes do not prove their
compilation from the approved SHA: the operator must establish that relationship
through the existing trusted release process before approving the preflight hash.
No candidate copy of sealed trusted-control scripts is executed.

`deployment` performs a single bounded read, not an automatic watch. Repeat it with
an explicitly identified run ID to obtain another immutable proof. Pending,
ambiguous, missing, failed or skipped required jobs/steps fail closed. Required job
names match the repository CD contract; renames need a reviewed tool update.

## Running and private storage

From the repository root:

```powershell
python -m tools.promotion --help
python -P -m unittest discover -s tools\tests -p test_promotion_tools.py -v
```

The module CLI needs the repository root on Python's module search path; the tests
use `-P` and explicitly insert the tools import directory.

Store evidence **outside the repository**, in an ACL-protected directory. Full ARM
and telemetry responses can contain sensitive data. Never commit or attach raw
bundles to PRs. The CLI rejects repository-local output and receipt paths. POSIX
creations use 0600/0700; Windows inherits the operator-secured parent directory ACL.

Each bundle is a unique UTC-microsecond + UUID directory containing `evidence.json`
and `manifest.json` with a SHA-256 of the exact evidence bytes. Exclusive fsynced
writes never replace earlier samples. Incomplete bundles fail verification. Hashes
detect accidental changes, not an attacker who can rewrite the entire store.

Commands use trusted explicit executable-word arrays, `shell=False`, and a per-call
timeout of 1..900 seconds. On Windows `azureCommand` can be an absolute Python path
followed by `-IBm`, `azure.cli`; elsewhere it can be `["az"]`. ARM reads use at most
four workers, cancel queued tasks on error, and await bounded in-flight calls.
Pagination rejects invalid/null shapes, cycles, changed resource/API scope, duplicate
GitHub items, changing totals, and more than 100 pages. No automatic retries.
Only public Azure ARM/Log Analytics endpoints are supported.

Context JSON has exactly these fields (synthetic identities):

```json
{
  "repository": "example/synthetic",
  "environment": "staging",
  "tenantId": "00000000-0000-0000-0000-000000000002",
  "subscriptionId": "00000000-0000-0000-0000-000000000001",
  "azureCommand": ["az"],
  "githubCommand": ["gh"],
  "timeoutSeconds": 75
}
```

`staging` and `prod` are supported. No tenant, subscription, run, SHA, resource,
deadline or approval defaults exist. Azure collectors verify the active account
against the configured tenant/subscription. Read-only operations include ARM
what-if and Log Analytics query POSTs, neither of which deploys resources.

## Preflight and snapshots

Preflight specification:

```json
{
  "sha": "<40 lowercase hex>",
  "template": "<absolute compiled ARM JSON path>",
  "parameters": "<absolute compiled parameter JSON path>",
  "location": "<explicit Azure location>",
  "deploymentName": "<explicit deployment name>",
  "snapshotUrls": ["https://management.azure.com/<exact resource ID>?api-version=<version>"],
  "decisions": []
}
```

Prepare compiled inputs using the existing trusted process. Hashes are recorded
and checked for mutation during collection, but their relationship to the SHA and
the completeness of selected snapshot coverage require operator review. Parameter
files are not archived; what-if responses may still contain sensitive values.

```powershell
python -m tools.promotion --context <context.json> --output <private-dir> preflight --spec <plan.json>
python -m tools.promotion --context <context.json> --output <private-dir> snapshot --preflight <bundle> --phase before
python -m tools.promotion --context <context.json> --output <private-dir> snapshot --preflight <bundle> --phase after-infra
python -m tools.promotion --output <private-dir> compare --before <bundle> --after <bundle>
```

Snapshot phase can also be `final`. Before snapshots must equal the entire
preflight GET collection including ETags; drift requires a new preflight.
Comparison reports changed URLs and never authorizes a write.

`NoChange` requires equal, present full payloads and no delta. Every other change,
including Ignore/NoEffect and metadata, needs an exact decision. Unknown shapes or
expressions are not guessed. Deleted parents cannot be hidden by child deltas.
Unused or duplicate decisions fail.

Decision shape:

```json
{
  "resourceId": "<exact ARM ID>",
  "resourceType": "<exact provider/type>",
  "path": "<literal what-if dotted path; empty for resource-level change>",
  "changeType": "Modify",
  "before": {"present": true, "value": "<exact typed value>"},
  "after": {"present": true, "value": "<exact typed value>"},
  "liveUrl": "https://management.azure.com/<same exact ID>?api-version=<version>",
  "livePointer": "/properties/<JSON pointer>",
  "liveState": {"present": true, "value": "<exact typed GET value>"},
  "approval": {
    "id": "<external decision reference>",
    "scope": {
      "repository": "<owner/repo>",
      "environment": "staging",
      "tenantId": "<UUID>",
      "subscriptionId": "<UUID>",
      "sha": "<40 lowercase hex>"
    },
    "approvedUtc": "<offset-aware timestamp>",
    "expiresUtc": "<offset-aware timestamp>",
    "reason": "<specific transition and supporting evidence reference>"
  }
}
```

Absence is `{"present": false}`, distinct from present JSON null. Boolean and
numeric values remain distinct. JSON pointers support `~0`/`~1` escapes; what-if
paths are compared literally. Approvals last at most two hours, are rechecked at
dispatch, and apply only to the exact bound transition. Each decision's singular
resource GET must be in `snapshotUrls`. No decisions are shipped with the tool.

## Provenance and single-use dispatch

```powershell
python -m tools.promotion --context <context.json> --output <private-dir> source --run <id> --sha <source-sha>
python -m tools.promotion --context <context.json> --output <private-dir> dispatch --authorization <approval.json> --preflight <bundle> --before <bundle> --receipts <canonical-private-ledger> --execute
python -m tools.promotion --context <context.json> --output <private-dir> deployment --run <identified-dispatch-id> --sha <approved-main-sha> --source-run <id> --source-sha <source-sha> --operation promotion
```

Dispatch authorization has exactly: `approval` (above), `operation` (`promotion`
or `rollback`), `sourceRunId` (positive decimal string), `sourceSha`,
`packageSha256`, `preflightHash`, `beforeHash`, `monitorHash` (null for promotion).
Bundle binding hashes are SHA-256 of **manifest bytes**, obtainable with
`promotion.common.binding`, not the inner evidence digest. External approval must
name those exact bindings. For promotion, source SHA equals approved main.

Source proof requires a successful exact-SHA main-push `cd-backend.yml` run, actual
build/retention steps in that attempt, and one unique logged package digest.
Dispatch rechecks source, main, all active dispatches, decisions and snapshot
bindings. Preflight age must be <=30 minutes; before snapshot age <=5 minutes.
Future timestamps fail.

The only mutation is the ordinary event with exactly three client payload fields:

```json
{"event_type":"promote-backend","client_payload":{"environment":"staging","operation":"promotion","source_run_id":"123"}}
```

A permanent exclusive approval-consumption record and request receipt are written
**before POST**. A separate accepted record means accepted, not deployed. Timeout
or process death leaves the request outcome unknown: reconcile read-only in GitHub,
never delete receipts and retry. Keep one canonical ledger across invocations;
changing it bypasses local single-use protection and is unsupported. Run correlation
is deliberately manual, not guessed from timing. No automatic POST retry.

Rollback is separate and requires fresh authorization, `--execute`,
`--monitor <original-live-monitor>`, and its exact `monitorHash`. It requires a
blocked observation <=5 minutes old and must happen strictly before the original
live hour ends. Ingestion grace, retrospective evidence, expired windows and
non-blocked monitors are ineligible. Fresh preflight/snapshot/source checks still
apply. **The monitor never dispatches rollback.**

## Rule, receivers and runtime observation

`observe --spec <file>` accepts exactly: `sha`, `ruleUrl`, `groupUrl`,
`ruleProperties`, `requiredReceivers`, `healthUrls`, `deploymentStatusUrl`,
`deploymentId`. `ruleProperties` maps JSON pointers to present/value states and
must include enabled=true, complete criteria/KQL, scopes, actions,
frequency, window and autoMitigate in the reviewed contract.
`healthUrls` has exactly `live` and `ready`; receivers are an explicit name list.

Use an action-group API exposing verification state (the repository checker
documents `2026-03-01-preview`). Every returned email receiver must be Enabled and
Verified with an address; the rule must reference that group. Contact details are
not copied into the proof. This does not prove actual email delivery.

Runtime is independent: RuntimeSuccessful with no errors/failed instances is only
an observation at that instant. BuildSuccessful, RuntimeStarting and unknown labels
are unconfirmed. RuntimeFailed, errors or failed instances remain failed even with
healthy HTTP probes. Missing fields fail closed. No JSON+HTML suffix workaround.

## Monitoring, gaps, interruptions and retrospective reads

Monitoring specification:

```json
{
  "resourceId": "<exact application insights ARM ID>",
  "workspaceId": "<workspace UUID>",
  "healthUrls": {"live": "https://<host>/api/health/live", "ready": "https://<host>/api/health/ready"},
  "ingestionSeconds": 240,
  "pollSeconds": 180
}
```

```powershell
python -m tools.promotion --context <context.json> --output <private-dir> baseline --spec <monitor.json> --sha <sha>
python -m tools.promotion --context <context.json> --output <private-dir> start-monitor --spec <monitor.json> --sha <sha> --baseline <bundle> --start <deployment-completion-with-offset>
python -m tools.promotion --context <context.json> --output <private-dir> monitor --monitor <bundle>
python -m tools.promotion status --monitor <bundle>
python -m tools.promotion --context <context.json> --output <private-dir> monitor --monitor <bundle> --resume
python -m tools.promotion --context <context.json> --output <private-dir> retrospective --monitor <bundle>
```

Baseline covers 24 hours, requires requests and availability, and ends <=2 hours
before deployment. Start is within ten minutes of deployment. The immutable header
binds baseline/config/SHA and original one-hour window. OS locking prevents concurrent
owners and releases on process death. Resume preserves window, history, counters
and gaps; it never starts a fresh hour.

Fixed queries cover AppRequests/AppAvailabilityResults/AppExceptions, each with
explicit resource and time predicates. No arbitrary KQL substitution or application
exception whitelist exists. Every sample has its own query/response, manifest and
previous-event hash. Invalid/partial HTTP-200 responses, missing columns/tables,
wrong types, null aggregates and duplicate rows are collection errors, not healthy
samples. Diagnostics are sanitized; sensitive stderr/error bodies are not dumped.

Conservative blockers: any request 5xx or availability failure, new exception type
relative to baseline, two consecutive direct health failures, two collection
failures (or one at/after window end), or empty/stale telemetry after ten minutes.
Final non-200 health blocks. Known exception types alone do not demonstrate a new
regression; this limited heuristic is not proof of all application behavior.

`complete` needs healthy evidence collected after hour+ingestion and no recorded
gaps. Failed collection, explicit resumption, and polling/collection gaps beyond
poll interval+60 seconds remain recorded. Otherwise healthy final data yields
`complete-with-gaps`, with a nonzero exit. Retrying reads never erases gaps.

Abrupt death leaves `incomplete-or-running`, never implicit completion. The status
reader does not claim process liveness. Partial bundles block resume pending manual
evidence reconciliation rather than being silently deleted. Expired live resume
is forbidden. Retrospective reads use the original window in a separate bundle,
never alter live history, have `continuousMonitoringProven: false`, and cannot
authorize rollback.

Exit 0 means the selected operation's stated evidence was recorded, not that all
promotion gates passed. Blocked/unconfirmed/incomplete returns 2; interruption 130.
`status` returns 0 only for `complete`.

## Validation and CI

```powershell
python -P -m unittest discover -s tools\tests -p test_promotion_tools.py -v
python -P -m unittest discover -s tools\tests -p "test_*.py" -v
python -m compileall -q tools\promotion tools\tests\test_promotion_tools.py
```

Tests are synthetic and forbid actual HTTP/subprocess execution. The existing
`ci-project-state.yml` runs Python tests from `.trusted-control` (PR base), not the
candidate tree. Its green status does not prove new tests ran: report local
candidate-tree results separately. No workflow or sealed trusted control is changed.
