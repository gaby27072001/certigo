using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;

namespace Certigo.Api.Observability;

public sealed class BuildIdentityTelemetryInitializer(BuildIdentity identity) : ITelemetryInitializer
{
    public void Initialize(ITelemetry telemetry)
        => telemetry.Context.Component.Version = identity.CommitSha ?? "unknown";
}
