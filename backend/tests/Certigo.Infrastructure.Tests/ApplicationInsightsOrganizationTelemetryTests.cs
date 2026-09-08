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

public sealed class ApplicationInsightsOrganizationTelemetryTests
{
    [Fact]
    public void Conflict_metric_contains_only_bounded_non_pii_dimensions()
    {
        var channel = new RecordingTelemetryChannel();
        var configuration = new TelemetryConfiguration
        {
            DisableTelemetry = false,
            TelemetryChannel = channel,
        };
        var telemetry = new ApplicationInsightsOrganizationTelemetry(
            new TelemetryClient(configuration),
            NullLogger<ApplicationInsightsOrganizationTelemetry>.Instance);

        telemetry.Track(new OrganizationTelemetryEvent(
            OrganizationTelemetryOperation.CreateInvitation,
            OrganizationTelemetryOutcome.Conflict,
            new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero),
            RequestChargeRequestUnits: 4.2,
            Count: 1));

        var metric = channel.Metrics.Should().ContainSingle().Which;
        metric.Name.Should().Be("organization_membership.shadow.operation");
        metric.Properties.Keys.Should().BeEquivalentTo(
            "component",
            "operation",
            "outcome",
            "requestChargeRequestUnits",
            "count");
        string.Join("|", metric.Properties.Values).Should().NotContain("@");
        metric.Properties.Should().NotContainKey("organizationId");
        metric.Properties.Should().NotContainKey("personId");
        metric.Properties.Should().NotContainKey("teamId");
        metric.Properties.Should().NotContainKey("email");
        metric.Properties.Should().NotContainKey("name");
    }

    [Fact]
    public void Observation_metric_reports_request_charge_and_count()
    {
        var channel = new RecordingTelemetryChannel();
        var configuration = new TelemetryConfiguration
        {
            DisableTelemetry = false,
            TelemetryChannel = channel,
        };
        var telemetry = new ApplicationInsightsOrganizationTelemetry(
            new TelemetryClient(configuration),
            NullLogger<ApplicationInsightsOrganizationTelemetry>.Instance);

        telemetry.Track(new OrganizationTelemetryEvent(
            OrganizationTelemetryOperation.ObserveTeamMembershipVolumetry,
            OrganizationTelemetryOutcome.Observed,
            new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero),
            RequestChargeRequestUnits: 2.5,
            Count: 0));

        var metric = channel.Metrics.Should().ContainSingle().Which;
        metric.Properties["operation"].Should().Be("ObserveTeamMembershipVolumetry");
        metric.Properties["outcome"].Should().Be("Observed");
        metric.Properties["requestChargeRequestUnits"].Should().Be("2.50");
        metric.Properties["count"].Should().Be("0");
    }

    [Fact]
    public void Capped_observation_reports_the_capped_dimension_so_the_count_is_never_read_as_exact()
    {
        var channel = new RecordingTelemetryChannel();
        var configuration = new TelemetryConfiguration
        {
            DisableTelemetry = false,
            TelemetryChannel = channel,
        };
        var telemetry = new ApplicationInsightsOrganizationTelemetry(
            new TelemetryClient(configuration),
            NullLogger<ApplicationInsightsOrganizationTelemetry>.Instance);

        telemetry.Track(new OrganizationTelemetryEvent(
            OrganizationTelemetryOperation.ObserveTeamMembershipVolumetry,
            OrganizationTelemetryOutcome.Observed,
            new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero),
            RequestChargeRequestUnits: 41.7,
            Count: 10_000,
            Capped: true));

        var metric = channel.Metrics.Should().ContainSingle().Which;
        metric.Properties["count"].Should().Be("10000");
        metric.Properties["capped"].Should().Be("True");
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
