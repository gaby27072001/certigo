# Dependabot Major Upgrade Plan

> Created: 2026-06-29  
> Context: Triage of 19 Dependabot PRs opened on 2026-06-23

## Summary

During the June 2026 Dependabot triage, the following PRs containing major version bumps were **deferred** because they require planned migrations with full test suite validation:

| PR | Package | Current | Target | Reason |
|----|---------|---------|--------|--------|
| #32 | `Microsoft.Azure.Functions.Worker` | 1.24.0 | 2.52.0 | Isolated worker model breaking changes |
| #33 | `Microsoft.Azure.Functions.Worker.ApplicationInsights` | 1.4.0 | 2.51.0 | Linked to Worker 2.x migration |
| #34 | `Microsoft.Azure.Functions.Worker.Sdk` | 1.18.1 | 2.0.7 | Linked to Worker 2.x migration |
| #31 | `Microsoft.ApplicationInsights.WorkerService` | 2.23.0 | 3.1.2 | AppInsights 3.x is a significant OpenTelemetry rewrite |
| #30 | `FluentAssertions` | 6.12.2 | 8.10.0 | Breaking changes introduced in v7+ |
| #25 | `google_fonts` (prism_ui) | 6.3.3 | 8.1.0 | Potential breaking changes in Flutter font loading API |

---

## Migration 1 — Azure Functions Worker 2.x

**Affected packages:** `Microsoft.Azure.Functions.Worker`, `Microsoft.Azure.Functions.Worker.ApplicationInsights`, `Microsoft.Azure.Functions.Worker.Sdk`

### Breaking changes to review
- Worker 2.x dropped support for several extension patterns used in 1.x
- Middleware and dependency injection pipeline changed
- `IFunctionWorkerApplicationBuilder` API changes
- Logging configuration via ApplicationInsights integration changed

### Migration steps
1. Create branch `upgrade/azure-functions-worker-2x`
2. Upgrade all three packages together (they must be upgraded atomically)
3. Fix compilation errors from API changes:
   - Check `Program.cs` worker host initialization
   - Review HTTP trigger bindings (`Functions.Worker.Extensions.Http` 3.x is included in PR #28)
   - Update `ILogger` injection patterns if changed
4. Run full backend test suite: `dotnet test backend/`
5. Deploy to a staging environment and verify Azure Functions host starts correctly
6. Validate telemetry in Application Insights portal

### References
- [Azure Functions Worker 2.x migration guide](https://github.com/Azure/azure-functions-dotnet-worker/releases)
- [Worker 2.0 release notes](https://github.com/Azure/azure-functions-dotnet-worker/blob/main/CHANGELOG.md)

---

## Migration 2 — Microsoft.ApplicationInsights 3.x (WorkerService)

**Affected package:** `Microsoft.ApplicationInsights.WorkerService`

### Breaking changes to review
- AppInsights 3.x aligns with OpenTelemetry — initialization model changed
- `TelemetryClient` configuration API updated
- `IServiceCollection.AddApplicationInsightsTelemetryWorkerService()` signature changes

### Migration steps
1. Create branch `upgrade/appinsights-3x` (coordinate with Functions Worker 2.x upgrade above — both affect telemetry)
2. Update the package
3. Review `Program.cs` / startup for `AddApplicationInsightsTelemetryWorkerService` call
4. Validate that telemetry flows correctly through integration tests
5. Check that custom telemetry initializers and processors still work

### References
- [AppInsights .NET 3.x changelog](https://github.com/microsoft/ApplicationInsights-dotnet/blob/main/CHANGELOG.md)

---

## Migration 3 — FluentAssertions 8.x

**Affected package:** `FluentAssertions` (used in test projects)

### Breaking changes to review
- v7 introduced a license change (commercial use may require a paid license)
- v7/v8 changed several assertion method signatures
- `Should().BeEquivalentTo()` options API changed
- Some obsolete assertions removed

### ⚠️ License warning
FluentAssertions 7+ changed from Apache 2.0 to a **commercial license** for closed-source projects. Evaluate if this applies to Microlingo/Certigo before upgrading.

### Alternative: Migrate to `Shouldly` or use `xunit` assertions directly (both MIT/Apache)

### Migration steps
1. Review license implications for the project
2. If upgrading, create branch `upgrade/fluentassertions-8x`
3. Run `dotnet test backend/` and fix each assertion error
4. Search for deprecated APIs: `ObjectExtensions`, `AndConstraint`, obsolete `Execute.Assertion`
5. Update `using` statements if namespace changed

### References
- [FluentAssertions 7.x migration guide](https://fluentassertions.com/upgradingtov7)
- [FluentAssertions 8.x release notes](https://github.com/fluentassertions/fluentassertions/releases)

---

## Migration 4 — google_fonts 8.x (Flutter / prism_ui)

**Affected package:** `google_fonts` in `/packages/prism_ui`

### Breaking changes to review
- Font caching behavior changed in 8.x
- `GoogleFonts.config` API may have changed
- Potential changes to how fonts are bundled in release builds

### Migration steps
1. Create branch `upgrade/google-fonts-8x`
2. Update `google_fonts` in `packages/prism_ui/pubspec.yaml`
3. Run `flutter analyze packages/prism_ui`
4. Run `flutter test packages/prism_ui`
5. Build a release APK/IPA and verify fonts render correctly on device

### References
- [google_fonts changelog](https://pub.dev/packages/google_fonts/changelog)

---

## PRs pending rebase (safe, will auto-merge after rebase)

The following PRs were triggered to rebase via `@dependabot rebase` on 2026-06-29. Once Dependabot rebases them and CI passes, they can be merged:

| PR | Package | Update type |
|----|---------|-------------|
| #28 | Group (Azure.Identity, xunit, Cosmos, JWT, etc.) | Minor/patch |
| #35 | `Microsoft.Bcl.Memory` 9.0.17 → 10.0.9 | Compatible library |
| #37 | `xunit.runner.visualstudio` 2.8.2 → 3.1.5 | Test tooling |
| #21 | `actions/checkout` 4 → 7 | GitHub Action |

---

## Completed in this triage (2026-06-29)

| PR | Package | Action |
|----|---------|--------|
| #19 | `github/codeql-action` 3 → 4 | ✅ Merged |
| #18 | `actions/setup-node` 4 → 6 | ✅ Merged |
| #17 | `actions/setup-dotnet` 4 → 5 | ✅ Merged |
| #20 | `actions/setup-python` 5 → 6 | ✅ Merged |
| #16 | `actions/upload-artifact` 4 → 7 | ✅ Merged |
| #22 | `lints` 4 → 6 (core) | ✅ Merged |
| #23 | `lints` 4 → 6 (cortex) | ✅ Merged |
| #24 | `lints` 4 → 6 (data) | ✅ Merged |
| #26 | `flutter_lints` 4 → 6 (prism_ui) | ✅ Merged |
| #32 | `Microsoft.Azure.Functions.Worker` 1 → 2 | 🚫 Closed (major — deferred) |
| #33 | `Microsoft.Azure.Functions.Worker.ApplicationInsights` 1 → 2 | 🚫 Closed (major — deferred) |
| #34 | `Microsoft.Azure.Functions.Worker.Sdk` 1 → 2 | 🚫 Closed (major — deferred) |
| #31 | `Microsoft.ApplicationInsights.WorkerService` 2 → 3 | 🚫 Closed (major — deferred) |
| #30 | `FluentAssertions` 6 → 8 | 🚫 Closed (major — deferred) |
| #25 | `google_fonts` 6 → 8 | 🚫 Closed (major — deferred) |
