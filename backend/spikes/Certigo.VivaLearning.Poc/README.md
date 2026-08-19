# Certigo Viva Learning POC

This .NET 8 executable is an isolated, offline contract spike. It is not
referenced by `Certigo.Api`, never acquires a token, and has no live mode. Its
`HttpClient` only runs against `FixtureGraphMessageHandler`.

The spike proves the request/response contracts for:

1. registering a `learningProvider`;
2. publishing a Certigo lesson as `learningContent`;
3. reading the signed-in user's `learningAssignment` objects;
4. resolving a Viva assignment to Certigo's existing
   `/lesson/:trackId/:lessonId` route;
5. updating assignment progress from `inProgress` to `completed`.

## Run

The feature flag is off by default:

```powershell
dotnet run --project backend\spikes\Certigo.VivaLearning.Poc -- --non-interactive
# exits 3 without issuing a request
```

Enable only the offline fixture replay:

```powershell
$env:CERTIGO_VIVA_LEARNING_POC_ENABLED = "true"
dotnet run --project backend\spikes\Certigo.VivaLearning.Poc -- --non-interactive
```

Without `--non-interactive`, the harness requires the operator to type
`SIMULATE`. The placeholder host is the reserved `.invalid` domain, so fixture
URLs cannot reach a real Certigo environment.

## Test

```powershell
dotnet test backend\tests\Certigo.Infrastructure.Tests\Certigo.Infrastructure.Tests.csproj `
  --filter "FullyQualifiedName~VivaLearningPocContractTests"
```

Live tenant validation is deliberately outside this executable. Follow
[`docs/runbooks/VIVA_LEARNING_POC_LIVE_VALIDATION.md`](../../../docs/runbooks/VIVA_LEARNING_POC_LIVE_VALIDATION.md)
only after explicit human approval.
