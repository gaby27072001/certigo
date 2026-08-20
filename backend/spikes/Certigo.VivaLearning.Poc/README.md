# Certigo Viva Learning POC

This .NET 8 executable is an isolated, offline contract spike. It is not
referenced by `Certigo.Api`, never acquires a token, and has no live mode. Its
`HttpClient` only runs against `FixtureGraphMessageHandler`.

The spike proves the request/response contracts for:

1. registering a `learningProvider`;
2. publishing a Certigo lesson as `learningContent`;
3. reading the signed-in user's `learningAssignment` objects;
4. publishing the stable #298 HTTPS ingress path
   `/learn/{trackId}/{lessonId}`, which the future mobile gate maps to the
   internal `/lesson/:trackId/:lessonId` route;
5. updating assignment progress from `inProgress` to `completed`.

## Run

The feature flag is off by default:

```powershell
dotnet run --project backend\spikes\Certigo.VivaLearning.Poc -- --non-interactive
# exits 3 without issuing a request
```

Enable only the offline fixture replay:

```powershell
$env:CERTIGO_VIVA_LEARNING_POC_OFFLINE_ENABLED = "true"
dotnet run --project backend\spikes\Certigo.VivaLearning.Poc -- --non-interactive
```

Without `--non-interactive`, the harness requires the operator to type
`SIMULATE`. The placeholder host is the reserved `.invalid` domain, so fixture
URLs cannot reach a real Certigo environment. The graph client constructor only
accepts `FixtureGraphMessageHandler`, and the content adapter rejects every
routable host.

The Graph `learnerUserId` is exposed as `EnterpriseLearnerObjectId` to make its
boundary explicit. The spike never resolves it to `Person`, never links an
identity, and never imports enterprise assignment state into personal mastery,
readiness, progression, rewards, or certification acquisitions.

## Test

```powershell
dotnet test backend\tests\Certigo.Infrastructure.Tests\Certigo.Infrastructure.Tests.csproj `
  --filter "FullyQualifiedName~VivaLearningPocContractTests"
```

Live tenant validation is deliberately outside this executable and remains
NO-GO. The non-executable prerequisite inventory is documented in
[`docs/runbooks/VIVA_LEARNING_POC_READINESS.md`](../../../docs/runbooks/VIVA_LEARNING_POC_READINESS.md).
