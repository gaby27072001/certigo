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
