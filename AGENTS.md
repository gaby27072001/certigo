# Certigo - Agent Instructions

## Build & Run

Run commands from the repository root unless a command changes directory.

```powershell
dart pub global activate melos
melos bootstrap
melos run format-check
melos run analyze
melos run test

Set-Location apps\mobile
flutter run

Set-Location backend
dotnet restore Certigo.sln
dotnet build Certigo.sln --configuration Release --no-restore -warnaserror
dotnet test Certigo.sln --configuration Release --no-build --verbosity normal

Set-Location src\Certigo.Api
Copy-Item local.settings.json.example local.settings.json
func start
```

Content and infrastructure checks:

```powershell
npm install
node tools\validate_content.mjs
python tools\seed_content.py
bicep build infra\main.bicep --stdout
bicep build-params infra\params\dev.bicepparam --stdout
```

`python tools\seed_content.py --cosmos` writes to Cosmos DB and requires explicit
credentials. Do not run it unless the user asks for a real data upload.

## Testing

- Dart packages: `dart test` from `packages\core`, `packages\cortex`, or
  `packages\data`.
- One Dart test: `dart test test\<file>_test.dart`.
- Mobile and Prism UI: `flutter test` from the relevant package.
- One Flutter test: `flutter test test\<file>_test.dart`.
- Mobile integration tests: `flutter test integration_test` from `apps\mobile`.
- Backend suite: `dotnet test backend\Certigo.sln`.
- One backend project:
  `dotnet test backend\tests\Certigo.Domain.Tests\Certigo.Domain.Tests.csproj`.
- One xUnit test:
  `dotnet test backend\tests\Certigo.Domain.Tests\Certigo.Domain.Tests.csproj --filter "FullyQualifiedName~ReadinessCalculatorTests"`.
- Prism renderer goldens:
  `flutter test test\rendering\renderer_golden_test.dart` from
  `packages\prism_ui`. CI runs them, like the app tests, with the Flutter
  release pinned by `FLUTTER_VERSION` in `.github\workflows\ci-mobile.yml`;
  read the version there rather than copying it. Regenerate goldens only with
  that release: CI judges them with it, not with your local Flutter.

Run the smallest relevant test first. Before completing changes, run the
matching format/analyze/build gate used by `.github\workflows`.

Browser authentication tests (OIDC, CIAM, social sign-in) run only in an
isolated, ephemeral browser context: a new context or a separately launched
browser, closed when the test ends. Never use a shared or persistent browser
profile, such as the shared Playwright MCP page: it may hold a person's real
sessions, and a test there can start a real sign-in on their account. Use
accounts created for the test, and delete them afterwards.

## Project Structure

- `apps\mobile` - Flutter application; feature-first UI, Riverpod providers,
  `go_router`, platform projects, widget tests, and integration tests.
- `packages\core` - dependency-free Dart primitives such as `Result`, failures,
  and environment configuration.
- `packages\cortex` - pure-Dart mastery, FSRS-style scheduling, session planning,
  readiness calculations, and per-type answer grading.
- `packages\data` - DTOs, API client, repositories, cache, and offline sync.
- `packages\prism_ui` - Prism design tokens, themes, reusable components, lesson
  rendering, and visual golden tests.
- `backend\src` - .NET 8 isolated Azure Functions organized as Domain,
  Application, Infrastructure, and API projects.
- `backend\tests` - xUnit projects mirroring backend architecture.
- `content` - certification tracks and lessons in YAML plus JSON schemas.
- `tools` - content validator and Cosmos seed tooling.
- `infra` - subscription-scoped Bicep entry point, modules, and environment
  parameter files.
- `docs` - architecture, ADRs, governance, release, migration, and runbooks.

Key entry points are `apps\mobile\lib\main.dart`,
`backend\src\Certigo.Api\Program.cs`, `tools\validate_content.mjs`, and
`infra\main.bicep`.

## Architecture Rules

- Keep mobile features under `apps\mobile\lib\features\<feature>` and shared
  composition in `lib\app` or `lib\shared`.
- Keep `packages\core` and `packages\cortex` independent of Flutter.
- Expose package APIs through their top-level library files instead of importing
  another package's `lib\src` paths.
- Preserve Clean Architecture dependency direction:
  `Domain <- Application <- Infrastructure/API`.
- The server is authoritative for quiz scoring, progression, rewards, and
  readiness. Client Cortex logic exists for responsive UX and must remain
  behaviorally equivalent to the .NET implementation.
- Derive `userId` from the validated JWT, never from a request body.
- Preserve quiz submission idempotency through `clientAttemptId`.
- Keep authored content schema-valid and preserve the separation between public
  quiz payloads and server-side answer keys.

## Code Style

- Dart uses 100-column formatting, single quotes, trailing commas, explicit
  return types, strict casts, and strict raw types. Prefer `final` locals and
  `const` constructors.
- Use Riverpod abstractions and provider overrides for dependency injection.
  Repositories return `Result<T>` so failures cross layers explicitly.
- C# targets .NET 8 with nullable reference types and implicit usings enabled.
  Use file-scoped namespaces, PascalCase public members, and async methods for
  I/O.
- Keep domain logic deterministic and pass time through `IClock` or an explicit
  `DateTimeOffset`/`DateTime` argument.
- Tests use descriptive behavior names. Backend assertions use
  FluentAssertions; Dart tests follow the existing `group`/`test` patterns.
- Add comments only for architectural invariants, security constraints, or
  non-obvious formulas.

## Project Agent Skills

- Project-scoped design and motion references live in `.agents/skills`; their
  provenance, license, selection, and update procedure are documented in
  `docs/AGENT_SKILLS.md`.
- Treat the installed upstream skills as design guidance, not as web stack
  requirements. Translate CSS, React, browser, and Motion examples to Flutter
  primitives and existing Prism components.
- `packages/prism_ui/lib/src/tokens/prism_motion.dart` remains authoritative
  for durations and curves. Extend existing Prism tokens instead of copying
  CSS timing values into Dart.
- Preserve `MediaQuery.disableAnimations` handling and the repository rule that
  motion is informative rather than decorative.
- Do not add JavaScript UI libraries, Flutter dependencies, or generated web
  scaffolding solely because an upstream skill recommends them.

## Git and CI

- Work on a feature branch; do not push directly to `main`.
- CI is path-scoped across mobile, backend, content, and infrastructure.
- Pull-request code executes on persistent self-hosted runners only after the
  repository's fork and environment guards. Preserve those guards.
- Treat warnings as errors for backend builds.
- Do not update generated Dart files manually. Run
  `melos run gen` when a package using `build_runner` requires regeneration.

## Boundaries

- **Always do:** add or update focused tests for behavior changes; preserve
  nullable/type safety; validate content changes; keep secrets in local settings
  or managed identity configuration; update documentation when an architecture
  or operational contract changes.
- **Ask first:** add dependencies; change public API or repository interfaces;
  alter Cosmos containers, partition keys, schemas, auth behavior, scoring
  formulas, readiness/FSRS parity, CI runner policy, signing, release workflows,
  or production Bicep parameters.
- **Never do:** commit `local.settings.json`, credentials, signing material, or
  generated seed output; expose quiz answer keys to clients; accept identity from
  request payloads; weaken production auth fallbacks; manually edit generated
  files; modify build output or third-party dependency directories; run an
  authentication test in a shared or persistent browser profile (see Testing).

## Documentation

- `README.md` - product overview, prerequisites, and quick-start commands.
- `docs\ARCHITECTURE.md` - full system architecture.
- `docs\ETAT_DU_PROJET.md` - current implementation status. Before recording any **volatile**
  fact there (counts, deployment state, "not yet done"), follow the convention
  "un fait volatil s'écrit une fois, daté et borné" in its "Régénération et politique de preuve"
  section: date it with a citable source, name the **real** invalidation condition rather than a
  narrower one, write it in exactly one place, and cross-reference by title rather than section
  number.
- `docs\adr` - architectural decision records.
- `docs\runbooks` and `docs\deployment-runbook.md` - operational procedures.
- `SECURITY.md` - vulnerability reporting and security expectations.
