using Certigo.Application.Abstractions;
using Microsoft.ApplicationInsights;
using Microsoft.Extensions.Logging;

namespace Certigo.Infrastructure.Observability;

public sealed class ApplicationInsightsPersonLinkedIdentityTelemetry(
    TelemetryClient telemetryClient,
    ILogger<ApplicationInsightsPersonLinkedIdentityTelemetry> logger)
    : IPersonLinkedIdentityTelemetry
{
    private const string MetricName = "person_linked_identity.shadow.operation";

    public void Track(PersonIdentityTelemetryEvent telemetryEvent)
    {
        var properties = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["component"] = "person_linked_identity.shadow",
            ["operation"] = telemetryEvent.Operation.ToString(),
            ["outcome"] = telemetryEvent.Outcome.ToString(),
        };
        AddIfPresent(properties, "provider", telemetryEvent.Provider);
        AddIfPresent(properties, "identityType", telemetryEvent.IdentityType);
        AddIfPresent(properties, "failureCode", telemetryEvent.FailureCode);
        AddIfPresent(properties, "exceptionType", telemetryEvent.ExceptionType);
        telemetryClient.TrackMetric(MetricName, 1, properties);

        if (telemetryEvent.Outcome
            is PersonIdentityTelemetryOutcome.Conflict
                or PersonIdentityTelemetryOutcome.Failed)
        {
            logger.LogWarning(
                "Person/LinkedIdentity shadow signal: Operation={Operation}, Outcome={Outcome}, "
                + "Provider={Provider}, FailureCode={FailureCode}, "
                + "ExceptionType={ExceptionType}.",
                telemetryEvent.Operation,
                telemetryEvent.Outcome,
                telemetryEvent.Provider,
                telemetryEvent.FailureCode,
                telemetryEvent.ExceptionType);
        }
    }
    private static void AddIfPresent(
        IDictionary<string, string> properties,
        string key,
        string? value)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            properties[key] = value;
        }
    }
}
