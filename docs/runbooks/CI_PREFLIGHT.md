# CI preflight and impact contract

## Scope

`CI preflight / Fast fail` is a fast, secret-free PR diagnostic. It does not
replace or rename any of the seven required stable checks and does not change a
live branch protection rule. GitHub loads the workflow and all control scripts
from `main` through `pull_request_target`; only same-repository PR source is
checked out on the `certigo-pr` pool.

The versioned source of path-selection truth is
`.github/ci/impact-matrix.json`. Every path runs `preflight`. Sensitive fixtures
also declare the gates they must select, and the test suite rejects a matrix
that lets one of those paths skip a declared gate. Rename detection evaluates
both the old and new path. Invalid diffs, paths, schemas, versions, gates and
outputs fail closed.

## Fast-fail order

1. Validate the trusted impact contract and the PR's candidate contract.
2. Run actionlint when workflow YAML or the contract changes.
3. Run adversarial selector tests and the trusted workflow security policy.
4. Resolve an explicit Python 3 launcher outside the untrusted checkout, require
   safe-path support, then validate project-state from the trusted generator
   against PR source.
5. Download the checksum-pinned Bicep CLI only for impacted IaC, then compile
   `infra/main.bicep` plus each changed extant Bicep or parameter source.

Heavy required workflows remain authoritative and continue to preserve coverage.
This P0 therefore improves feedback time for invalid workflow, policy,
project-state and Bicep changes; it does not claim to reduce the duration of a
fully green application build. A later PR may make existing selectors consume
the impact contract after run evidence proves parity.

## Baseline and expected gain

The baseline was captured on 2026-08-31 from the latest 100 Actions runs on
`origin/main`. Successful-run wall times include self-hosted queueing:

| Workflow | Runs | Median | Mean | Range |
|---|---:|---:|---:|---:|
| `security-gate` | 12 | 268 s | 786 s | 121-5,455 s |
| `ci-infra` | 6 | 244 s | 370 s | 238-843 s |
| `Validate generated project state` | 11 | 158 s | 213 s | 21-839 s |
| `Lint GitHub Actions workflows` | 7 | 28 s | 212 s | 25-878 s |

For a defect otherwise discovered by the project-state or IaC gate, one
preflight runner is expected to return the same class of failure in 30-90 s
instead of the observed 158-244 s median: 43-88% faster feedback, depending on
runner queue and whether Bicep is applicable. Re-measure after 20 preflight runs;
do not treat queue-inclusive estimates as an SLA.

## Adversarial pre-push checklist

Run from the repository root before pushing CI changes:

```powershell
npm ci --ignore-scripts
node --test .github/scripts/ci-impact.test.mjs .github/scripts/workflow-security-cache-policy.test.mjs
node .github/scripts/validate-workflow-security.mjs
python -P -m unittest discover -s tools/tests -p "test_*.py" -v
python -P tools/project_state.py --check
actionlint .github/workflows/*.yml
```

For Bicep changes, also run:

```powershell
bicep build infra/main.bicep --stdout
bicep build-params infra/params/dev.bicepparam --stdout
```

Before approval, confirm the PR cannot:

- execute fork source on a persistent runner;
- source selectors or validators from the PR checkout;
- receive secrets, environments, credentials or cloud identity on `certigo-pr`;
- weaken the default `preflight` fallback or a sensitive assertion;
- omit workflow, project-state, dependency, CodeQL or IaC gates for a sensitive
  path;
- alter required checks, branch protection, rulesets or deployment state.

## Rollout and rollback

The preflight is additive and initially non-required. Compare its selected gates
with existing workflow decisions for at least 20 representative PR runs,
including workflow, dependency, backend, mobile, content and IaC changes. A
future ruleset change is out of repository scope and requires explicit operator
approval.

Rollback is deletion of the additive workflow after preserving its run evidence.
Do not remove the impact matrix while scripts or tests consume it, and never
remove or rename a stable required context as part of rollback.
