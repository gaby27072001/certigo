using System.Globalization;
using Certigo.Application.Abstractions;
using Microsoft.ApplicationInsights;
using Microsoft.Extensions.Logging;

namespace Certigo.Infrastructure.Observability;

/// <summary>
/// Non-PII telemetry sink for Organization/Membership shadow mode. Mirrors
/// <see cref="ApplicationInsightsPersonLinkedIdentityTelemetry"/>: bounded dimensions only
/// (operation, outcome, request charge, count, capped) — never an organization id, person id,
/// e-mail, or name.
/// </summary>
public sealed class ApplicationInsightsOrganizationTelemetry(
    TelemetryClient telemetryClient,
    ILogger<ApplicationInsightsOrganizationTelemetry> logger)
    : IOrganizationTelemetry
{
    private const string MetricName = "organization_membership.shadow.operation";

    public void Track(OrganizationTelemetryEvent telemetryEvent)
    {
        var properties = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["component"] = "organization_membership.shadow",
            ["operation"] = telemetryEvent.Operation.ToString(),
            ["outcome"] = telemetryEvent.Outcome.ToString(),
        };
        AddIfPresent(
            properties,
            "requestChargeRequestUnits",
            telemetryEvent.RequestChargeRequestUnits?.ToString(
                "F2",
                CultureInfo.InvariantCulture));
        AddIfPresent(
            properties,
            "count",
            telemetryEvent.Count?.ToString(CultureInfo.InvariantCulture));
        AddIfPresent(
            properties,
            "capped",
            telemetryEvent.Capped?.ToString(CultureInfo.InvariantCulture));
        telemetryClient.TrackMetric(MetricName, 1, properties);

        if (telemetryEvent.Outcome
            is OrganizationTelemetryOutcome.Conflict
                or OrganizationTelemetryOutcome.Failed)
        {
            logger.LogWarning(
                "Organization/Membership shadow signal: Operation={Operation}, Outcome={Outcome}, "
                + "RequestChargeRequestUnits={RequestChargeRequestUnits}, Count={Count}, "
                + "Capped={Capped}.",
                telemetryEvent.Operation,
                telemetryEvent.Outcome,
                telemetryEvent.RequestChargeRequestUnits,
                telemetryEvent.Count,
                telemetryEvent.Capped);
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
