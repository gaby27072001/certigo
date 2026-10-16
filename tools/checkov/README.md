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

## Separate conditional-resource adapter candidate

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
adapter source are pinned in `build_checkov_wheel.py`. Every other package file,
including licenses and notices, is preserved. Only distribution metadata,
RECORD, a modification notice and the reviewed adapter source change.
The patch text alone is canonicalized from a CRLF or LF checkout to LF before
checking its pinned digest; upstream and resulting package bytes are never
normalized or accepted under alternate digests.

The input is the unmodified `checkov-3.2.495-py3-none-any.whl`:
SHA-256 `737f39cbab5987d49204cd5e62cfca72ffab3f01fa3314471624e1c4256268ac`.
The builder is offline and the candidate output has local version
`3.2.495+certigo.1`, SHA-256
`0b85efb56fd23a5eab69a59726b4d2a47f05af84416137ede4ac14974289b3af`.

```sh
CHECKOV_ADAPTER_UPSTREAM_WHEEL=/path/checkov-3.2.495-py3-none-any.whl \
  python tools/checkov/test_checkov_wheel.py
python tools/checkov/build_checkov_wheel.py /path/checkov-3.2.495-py3-none-any.whl /tmp/checkov-wheel
python -m pip install --no-deps --target /tmp/checkov-adapter /tmp/checkov-wheel/checkov-3.2.495+certigo.1-py3-none-any.whl
PYTHONPATH=/tmp/checkov-adapter:/tmp/parser-runtime python tools/checkov/test_conditional_adapter.py
```

Use a separate environment with Checkov's pinned dependencies and the reviewed
parser runtime. The adapter tests require the modified Checkov distribution and
verify its installed source digest. Their synthetic controls exercise the four
VMSS property checks, secure/insecure bodies, symbolic property values, malformed
wrappers, preserved inputs, unchanged unconditional/existing behavior, and a real
UNKNOWN check retained as a failed runner record. No rule ID is excluded.
This candidate changes no official workflow or infrastructure. It requires its
own review and explicit activation, separate from the parser-only delivery.
