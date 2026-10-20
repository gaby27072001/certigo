# Pinned Bicep parser compatibility patch

This is a local, reviewable source patch to `gruebel/pycep` **0.5.1**, the parser
required by Checkov **3.2.495**. It is not a Bicep source preprocessor, ARM
replacement, new expression evaluator, or suppression list.

Upstream: <https://github.com/gruebel/pycep>. License: **Apache-2.0**. The
upstream wheel's complete license is retained; the resulting wheel includes a
modification notice. No Certigo source is included in the wheel or upstream patch.
Nothing is uploaded upstream by this tooling.

The patch adds multiline function/conditional syntax, unrestricted consecutive
object comments, and symbolic `range`, `map`, `reduce`, `toObject`, and `fail`
nodes. Existing accepted ASTs and range loops retain their previous structure.
It does not invent safe literal values for unknown expressions.

## Reproduce without modifying an installed package

Download the public upstream wheel, verifying its SHA-256 before use:

- URL: <https://files.pythonhosted.org/packages/99/56/01afa944d13dcc2586086c4d1312c43e5bad7f8f9b3473bf0a777a616d90/pycep_parser-0.5.1-py3-none-any.whl>
- SHA-256: `8c3f99c0dc1301193b1bcbe0a44c6b2763f6d2daf24964ca48dcdfbb73087fa0`

Run from the repository root in an isolated environment with Checkov 3.2.495 and
Git already installed:

```sh
CHECKOV_UPSTREAM_WHEEL=/path/pycep_parser-0.5.1-py3-none-any.whl \
  python tools/checkov/test_parser_wheel.py
python tools/checkov/build_parser_wheel.py /path/pycep_parser-0.5.1-py3-none-any.whl /tmp/parser-wheel
python -m pip install --no-deps --target /tmp/parser-runtime /tmp/parser-wheel/pycep_parser-0.5.1+certigo.1-py3-none-any.whl
CHECKOV_UPSTREAM_WHEEL=/path/pycep_parser-0.5.1-py3-none-any.whl \
  PYTHONPATH=/tmp/parser-runtime python tools/checkov/test_parser_compat.py
```

The builder has no network access. It verifies the complete upstream wheel,
patch, and both patched source digests; applies only the reviewed patch; preserves
unmodified package files; writes local version `0.5.1+certigo.1`; regenerates
`RECORD`; and emits a deterministic wheel:
`8e50661d796af4bc738294db0be82766db625b9490ff6fd59aa11363e437bc0f`.
Changed inputs, patch drift, or unexpected outputs fail the build.
Patch application pins Git's line endings and disables external attributes for
that process only. ZIP entries explicitly use Unix metadata on every platform.
The standalone builder tests require only Python's standard library and Git,
including hostile global `autocrlf=true/false` and CRLF attributes; they require
the same final wheel digest on Windows and Linux. They do not require Checkov.

Use that same isolated runtime for the existing Checkov command, without
`--quiet`, retaining the existing trusted configuration and strict JSON gate.
Tests exercise every current Bicep source, compare all upstream-accepted ASTs,
reject malformed/unknown functions, and run actual Checkov negative controls on
literal, multiline, mapped and unknown parameter values.

Parsing success is not exhaustive security coverage. Existing Checkov rule and
expression-evaluation limitations remain; unknown values are not certified safe
by this patch. In particular, Checkov 3.2.495's `Report.add_record` does not retain
`UNKNOWN` results in its JSON lists. The negative controls require actual `FAILED`
records for the unknown HTTPS parameter; they do not establish that every rule
fails closed for every symbolic expression. Real findings must remain blocking.
Workflow installation and activation require ordinary reviewed
preapproval/consumption; adding these files
alone changes no CI runtime, checks, infrastructure, or dependency installation.

## Separate conditional-resource and bounded rule-fix candidate

`checkov-3.2.495-conditional.patch` changes only Checkov's ARM-resource-check
adapter used by Bicep. The parser AST stays unchanged. Its `{condition, config}`
wrapper is not an Azure resource body: the adapter now checks the inner body
without interpreting, deleting, or relying on its guard. Both a literal false
guard and an unresolved guard still cause the potentially deployable body to be
checked. A secure body can pass those property checks; that is not a claim that
the deployment condition is known or satisfied.

Malformed wrappers and `UNKNOWN` results from checks on conditional bodies
produce explicit failed results and warning diagnostics instead of disappearing
from Checkov's report. Unknown property values are exercised separately from
unknown deployment guards. This is not a general expression evaluator or a
global repair of Checkov's UNKNOWN handling, graph checks, loop handling,
module parameter contexts, or other rule applicability defects.

Upstream is Checkov 3.2.495, <https://github.com/bridgecrewio/checkov>,
Apache-2.0. The upstream wheel, adapter source, canonical LF patch, and resulting
adapter source are pinned in `build_checkov_wheel.py`. The two separately pinned
identity and Cosmos rule patches below are also applied. Every other package file,
including licenses and notices, is preserved. Only distribution metadata,
RECORD, a modification notice and the three reviewed source files change.
The patch text alone is canonicalized from a CRLF or LF checkout to LF before
checking its pinned digest; upstream and resulting package bytes are never
normalized or accepted under alternate digests.

The input is the unmodified `checkov-3.2.495-py3-none-any.whl`:
SHA-256 `737f39cbab5987d49204cd5e62cfca72ffab3f01fa3314471624e1c4256268ac`.
The builder is offline and the candidate output has local version
`3.2.495+certigo.4`, SHA-256
`6309f6782d64568ee03648bb8ec7b6e5b0839ccde4f335c4f1cba8f7486e8c69`.

```sh
CHECKOV_ADAPTER_UPSTREAM_WHEEL=/path/checkov-3.2.495-py3-none-any.whl \
  python tools/checkov/test_checkov_wheel.py
python tools/checkov/build_checkov_wheel.py /path/checkov-3.2.495-py3-none-any.whl /tmp/checkov-wheel
python -m pip install --no-deps --target /tmp/checkov-adapter /tmp/checkov-wheel/checkov-3.2.495+certigo.4-py3-none-any.whl
PYTHONPATH=/tmp/checkov-adapter:/tmp/parser-runtime python tools/checkov/test_conditional_adapter.py
PYTHONPATH=/tmp/checkov-adapter:/tmp/parser-runtime python tools/checkov/test_resource_rule_fixes.py
```

Use a separate environment with Checkov's pinned dependencies and the reviewed
parser runtime. The adapter tests require the modified Checkov distribution and
verify its installed source digest. Their synthetic controls exercise the four
VMSS property checks, secure/insecure bodies, symbolic property values, malformed
wrappers, preserved inputs, unchanged unconditional/existing behavior, and a real
UNKNOWN check retained as a failed runner record. No rule ID is excluded.
This candidate changes no official workflow or infrastructure. It requires its
own review and explicit activation, separate from the parser-only delivery.

`checkov-3.2.495-identity.patch` fixes CKV_AZURE_16's exact-string rejection of
Azure's combined `SystemAssigned, UserAssigned` identity type. A literal
system-assigned identity establishes this rule's property independently of any
unresolved user-assigned identity map. A user-assigned-only identity instead
requires a nonempty map of literal, fully qualified UAMI resource IDs with empty
configuration objects. Empty, malformed, symbolic or otherwise unknown-only
assignments fail; this is configuration proof, not proof that an identity exists
in Azure. Unknown identity types are explicit failures, never UNKNOWN records.

`checkov-3.2.495-cosmos.patch` fixes CKV_AZURE_99's rejection of literal
`publicNetworkAccess: 'Disabled'`. A closed public endpoint needs no public
firewall exception to satisfy this rule. For public access, explicit VNet
filtering and nonempty known subnet-ID or IPv4 restrictions are required.
`enableMultipleWriteLocations: false` no longer bypasses restrictions.
IP validation uses Python's standard `ipaddress` module, without network access
or an expression evaluator. The all-addresses range, both IPv4 `/1` halves,
Azure's `0.0.0.0` exception,
IPv6/unsupported inputs, symbolic IDs/IPs, malformed rules and unresolved flags
remain blocked. It does not validate subnet existence, authorize an address,
or introduce a new permitted-CIDR policy.

Revision `certigo.3` rejects both `0.0.0.0/1` and `128.0.0.0/1` symmetrically;
the earlier `certigo.2` candidate rejected only the former. Direct-rule and real
runner controls retain explicit failures for both halves. No additional CIDR
size threshold or address allowlist is introduced. Any consumption proposal
pinning the earlier wheel is stale and must be reviewed again before activation.

### ARM composition qualification, not ARM gate adoption

Revision `certigo.4` corrects an ARM-only false rejection in the existing identity
predicate; it does not introduce a second rule engine or a framework switch.
`checkov/arm/parser/parser.py:load` uses
`checkov/common/parsers/yaml/loader.py:SafeLineLoader.construct_mapping` even for
ordinary JSON templates. The loader inserts integer `__startline__` and
`__endline__` keys in **every** mapping, including `{}`. A fully qualified UAMI
map consequently has two extra entries, and each empty identity configuration
also has two entries. Revision `certigo.3` incorrectly rejected both shapes.

The identity predicate now removes exactly these two reserved keys at the
assignment-map and assignment-configuration levels, only when their integer,
positive, ordered bounds are contained in the resource's own line bounds.
Missing, noninteger, Boolean, reversed, out-of-resource or unanchored markers
fail. `__file__` and all other unknown keys remain failures. The resulting
assignment map must still be nonempty, all identity IDs must be fully qualified,
and every configuration must be empty after this bounded normalization.
Inputs are not mutated. This relies on the pinned loader's reserved-key
contract; it is not raw ARM schema validation and cannot recover authored
reserved keys overwritten by that loader.

`test_arm_composition.py` runs the real ARM Runner against the original 18
probe shapes with candidate expectations, plus paired literal-ID and malformed
controls. In particular, empty user-assigned maps and unrestricted public
Cosmos with `enableMultipleWriteLocations=false` now produce actual FAILED
records. Private Cosmos and mixed/system identities produce PASSED records.
The original short `/identities/example` and `/subnets/example` pseudo-IDs now
fail deliberately; separate fully qualified IDs provide the positive controls.
All six appsettings failures, sibling/parent results, unresolved ingress
failure and empty-template lack of coverage remain observable.

```sh
PYTHONPATH=/tmp/checkov-adapter python tools/checkov/test_arm_composition.py
```

This test needs the existing candidate wheel and Checkov's pinned dependencies;
it does not need a parser override or scan `infra`. An empty ARM template still
has no executed checks: the fixture records that limitation, never conformity.
No gate may accept it or drop UNKNOWN/parse/skipped records as coverage.
This bounded fix does **not** implement the missing environment/module binding,
parent/subtype applicability ledger, Flex capability predicates or exhaustive
source-to-ARM coverage reconciliation. Those remain blockers, not implicit
exceptions. In particular, this candidate is not adoptable as an ARM replacement
for the active Bicep gate. A proposal must separately approve the coverage/report
contract and its fail-closed negative controls before changing any workflow,
trusted-control manifest, framework, scanner consumption or gate version pin.
No such protected file is changed here; proposals pinning `certigo.3` must be
updated and re-reviewed rather than silently consuming this revision.

### Exact fixture coverage is distinct from a successful scan

The inactive composition harness now uses `require_fixture_coverage` for
explicit `(resource, check)` obligations. This is deliberately a **single-file
fixture assertion**, not a production inventory, applicability ledger, new
policy evaluator, or replacement for `.github/scripts/checkov_report_gate.py`.
It rejects empty/duplicate obligations, missing/extra/duplicate evidence,
inconsistent statuses, parsing errors, skips and a report without executed
checks. It returns the retained PASSED/FAILED evidence; a FAILED record is
coverage, never security success. The fully qualified identity/subnet positive
controls exercise the assertion directly.

The concrete missing-coverage regression is a real ARM template with a
`Microsoft.Web/sites` parent whose ingress is Disabled and an embedded short-type
`config` child named `appsettings`. With only checks 13 and 222 selected, the
pinned candidate produces **one PASSED parent record, zero failed/skipped/parse
records and two scanner resources**. No child-13 record survives. The expected
child obligation makes the fixture assertion fail even though a coarse
nonempty-resource/nonempty-check test would pass. This is a qualification
boundary of the runner, not a claim that the active Bicep gate accepts ARM
reports: that gate explicitly requires the Bicep framework.

A paired control starts from two actual successful site checks, then injects a
test-only UNKNOWN response for one check. The report loses only that check,
leaving the other success intact; exact obligations reject the loss. Additional
controls retain an unsafe parent's ingress failure and all six ordinary
appsettings failures, and reject damaged report evidence. No UNKNOWN is changed
to PASSED, no child failure is removed, and installed scanner code is not patched
by these tests.

Run just the new coverage qualification and its directly affected positive
control, without rerunning the 18-shape suite or scanning the repository:

```sh
cd tools/checkov
python -m unittest -v \
  test_arm_composition.CompositionTests.test_nested_short_type_child_disappears_despite_success_and_two_resources \
  test_arm_composition.CompositionTests.test_unknown_check_with_other_success_cannot_meet_exact_obligations \
  test_arm_composition.CompositionTests.test_failed_parent_and_all_six_child_failures_remain_coverage_not_success \
  test_arm_composition.CompositionTests.test_exact_fixture_obligations_reject_empty_duplicate_skip_parse_and_foreign \
  test_arm_composition.CompositionTests.test_literal_qualified_user_and_subnet_positive_controls
```

Use an isolated environment containing the existing digest-verified
`3.2.495+certigo.4` wheel and its dependencies. These controls were also run with
CPython 3.12.15 on Linux aarch64, pycep-parser 0.5.1 and PyYAML 6.0.3. This closes
the Python-minor qualification gap for these fixtures only; it is not CI x64
or deployment evidence and does not validate other policies.

Before adopting a production coverage contract, an independently derived
inventory must bind source revision, environment and module instance to each
required resource/check pair, retaining explicit non-applicability separately
from parent security verdicts. An inventory derived only from returned records
cannot detect omitted checks. Parameter/default evaluation is not evidence of
the selected environment's module arguments. Unknown subtype, unresolved
binding, missing parent/module, UNKNOWN response, parse error and zero effective
coverage must each remain blocking. Neither that architecture nor a runtime
or gate change is implemented by this fixture-only delivery.

### First inactive Bicep applicability adapter: literal root ingress

`bicep_ingress_candidate.py` implements a deliberately small next step using
the **existing Bicep Runner and unchanged CKV_AZURE_222 predicate**, not another
policy engine. It parses authored source before scanning to derive independent
resource/check obligations, and pins the installed ingress and registry source
digests as well as candidate and parser versions. Both parser and scanner
consume the same captured source bytes (the Runner uses a temporary snapshot).
The versioned JSON includes the original source path/hash, explicit environment,
root module instance, independent obligations, unmodified raw scanner report,
separate applicability records and blockers.

Only API `2024-04-01`, resource-group scope, a literal
`Microsoft.Web/sites` resource containing just `name` and
`properties.publicNetworkAccess`, and its symbolic-parent-linked literal
`Microsoft.Web/sites/config` `appsettings` StringDictionary are qualified.
Site names and per-site appsettings children must be unique. Parameters,
variables, modules, outputs, conditions, loops, other properties/resources,
unresolved values and other subtypes fail closed **before** the Runner.
An environment label does not resolve a parameter: this lot rejects all
parameter declarations and supports only the root module instance.

For each appsettings child, ingress applicability is explicitly
`NOT_APPLICABLE` with a typed-contract reason and the separately reconciled site
obligation. The child's raw CKV_AZURE_222 FAILED record remains in
`scanner_report`, including its raw summary; it is not deleted, changed to
PASSED or returned as UNKNOWN. The parent's actual predicate result remains
independent: an Enabled parent blocks even with a non-applicable child.
Missing child or parent evidence, duplicate/unexpected obligations, UNKNOWN
omissions, parsing/skipped records and inconsistent cardinality/status block.
This custom applicability schema is experimental, **not** an existing Checkov
result status or an adopted production report contract.

```sh
python tools/checkov/bicep_ingress_candidate.py /path/literal-fixture.bicep --environment staging
python tools/checkov/test_bicep_ingress_candidate.py
```

Exit 0 means only `QUALIFIED_SUBSET` under that narrow contract; every report
sets `production_adoptable: false` and names the restricted control scope.
It does not claim every security control on these resources was checked.
Exit 1 means BLOCKED. The actual `infra/modules/functionApp.bicep` is outside
this literal-only contract and must remain blocked: parameters, module binding,
Flex runtime/diagnostics and ingress decisions are not implemented or inferred.
The other five appsettings checks retain their prior findings; this tool does
not run, suppress or resolve them. There is no active gate/workflow, dependency
pin, infrastructure, cloud access or scanner installation change.

All six appsettings-subtype findings remain unchanged and blocking. Returning
PASSED on an inapplicable appsettings child would misrepresent the parent;
returning UNKNOWN would silently lose the record in this Checkov version.
Resolving them needs an explicit applicability/parent-context reporting
contract, not a rule-ID exclusion. The other environment-dependent, platform
UNKNOWN and product-decision findings likewise remain open. These focused
controls do not establish any reduced total-finding count.

### Appsettings applicability: blocked reporting contract

The six unchanged upstream checks accept the shared
`Microsoft.Web/sites/config` resource type, not a discriminated configuration
subtype. The [2024-04-01 Microsoft schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.web/2024-04-01/sites/config)
distinguishes `appsettings` (`StringDictionaryProperties`), `web` (`SiteConfig`),
`authsettings` (`SiteAuthSettingsProperties`) and `azurestorageaccounts`
(`AzureStoragePropertyDictionaryResourceProperties`). Same ARM type does not
mean same property contract.

| Check | Current inspected contract | Applicability boundary |
| --- | --- | --- |
| CKV_AZURE_13 | `authsettings.properties.enabled` | Not application environment variables; V2 auth needs a separate contract. |
| CKV_AZURE_80 | `properties.netFrameworkVersion == 'v8.0'` | A `web` runtime property, not an appsetting or proof of Flex runtime configuration. |
| CKV_AZURE_66 | `properties.requestTracingEnabled` | A `web` tracing property, not an appsetting or proof of supported Flex diagnostics. |
| CKV_AZURE_63 | `properties.httpLoggingEnabled` | A `web` logging property, not an appsetting. |
| CKV_AZURE_222 | `properties.publicNetworkAccess == 'Disabled'` | Site/slot ingress or `web` configuration, not an appsetting. The parent site's separate result must survive. |
| CKV_AZURE_88 | `properties.azureStorageAccounts.*.type == 'AzureFiles'` | A `web` mount shape, not appsettings; the separate `azurestorageaccounts` subtype has a different dictionary shape. It does not establish that every hosting plan needs Azure Files. |

The minimal safe target would distinguish known non-applicable children from
unknown subtypes and unresolved parent/module context, retain explicit
applicability evidence keyed by resource/check, and independently reconcile the
actual applicable parent or child checks. Non-applicability is not security
success and does not certify an absent parent.

That contract is **not available in the pinned runner**:

- `CheckResult` has only PASSED, FAILED, UNKNOWN and SKIPPED. There is no
  non-applicable result. `Report.add_record` retains only the first, second and
  fourth; UNKNOWN has no output record or per-check summary.
- The Bicep Python registry dispatches by full resource type and passes the
  current resource AST, without resolving the referenced parent's configuration.
  Of these six rules, only CKV_AZURE_222 is also registered on a site parent.
  Narrowing the other rules to parent sites does not move their property lookup
  into `siteConfig` or prove missing child configurations were checked.
- Returning UNKNOWN for the six ordinary appsettings checks loses all six
  records while keeping one scanned resource and zero parsing errors. This is
  not fixed by resource counts. Returning SKIPPED is a suppression; returning
  PASSED asserts the wrong property. Neither is an acceptable workaround.
- Synthetic `web`/`authsettings` fixtures prove secure/insecure/unresolved
  property results, not cloud capability or deployment validity. Deliberately
  injecting web-shaped properties into appsettings demonstrates the missing
  subtype gate, not a proposed schema-valid deployment fix. Even string-valued
  environment variables named `netFrameworkVersion` and `publicNetworkAccess`
  can produce irrelevant successes for CKV_AZURE_80 and CKV_AZURE_222.

`test_appsettings_applicability.py` pins the six unchanged rule source digests
and reproduces these boundaries using small isolated Runner fixtures, including
secure/insecure/unresolved/absent parent cases, exact authored appsettings AST,
and a test-only mocked UNKNOWN workaround. Its expected outcomes deliberately
retain the six failures. It does not patch installed Checkov, change the wheel,
or scan the infrastructure tree:

```sh
PYTHONPATH=/tmp/checkov-adapter:/tmp/parser-runtime python tools/checkov/test_appsettings_applicability.py
```

No additional scanner patch is included for these six findings. Fixing the
report/result schema plus subtype-aware parent coverage would cross the
bounded adapter scope and requires a separately reviewed contract; the existing
findings remain blocking until then.
