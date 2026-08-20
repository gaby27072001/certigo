using Certigo.Application.Abstractions;
using Certigo.Infrastructure.Observability;
using FluentAssertions;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class ApplicationInsightsPersonLinkedIdentityTelemetryTests
{
    [Fact]
    public void Failure_metric_contains_only_bounded_non_pii_dimensions()
    {
        var channel = new RecordingTelemetryChannel();
        var configuration = new TelemetryConfiguration
        {
            DisableTelemetry = false,
            TelemetryChannel = channel,
        };
        var telemetry = new ApplicationInsightsPersonLinkedIdentityTelemetry(
            new TelemetryClient(configuration),
            NullLogger<ApplicationInsightsPersonLinkedIdentityTelemetry>.Instance);

        telemetry.Track(new PersonIdentityTelemetryEvent(
            PersonIdentityTelemetryOperation.Reconciliation,
            PersonIdentityTelemetryOutcome.Conflict,
            new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero),
            "entra-external-id",
            "entraExternalId",
            "identity_already_linked",
            nameof(IdentityAlreadyLinkedException)));

        var metric = channel.Metrics.Should().ContainSingle().Which;
        metric.Name.Should().Be("person_linked_identity.shadow.operation");
        metric.Properties.Keys.Should().BeEquivalentTo(
            "component",
            "operation",
            "outcome",
            "provider",
            "identityType",
            "failureCode",
            "exceptionType");
        string.Join("|", metric.Properties.Values).Should().NotContain("@");
        metric.Properties.Should().NotContainKey("personId");
        metric.Properties.Should().NotContainKey("userId");
        metric.Properties.Should().NotContainKey("subject");
        metric.Properties.Should().NotContainKey("email");
    }

    private sealed class RecordingTelemetryChannel : ITelemetryChannel
    {
        public List<MetricTelemetry> Metrics { get; } = [];

        public void Send(ITelemetry item)
        {
            if (item is MetricTelemetry metric)
            {
                Metrics.Add(metric);
            }
        }
        public void Flush() { }
        public bool? DeveloperMode { get; set; }
        public string? EndpointAddress { get; set; }
        public void Dispose() { }
    }
}
