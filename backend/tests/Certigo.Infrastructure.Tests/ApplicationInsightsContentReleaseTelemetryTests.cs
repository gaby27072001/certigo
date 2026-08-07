using Certigo.Application.Dtos;
using Certigo.Infrastructure.Observability;
using FluentAssertions;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class ApplicationInsightsContentReleaseTelemetryTests
{
    [Fact]
    public void Emits_import_promotion_rejection_and_rollback_events()
    {
        var channel = new RecordingTelemetryChannel();
        var telemetry = new ApplicationInsightsContentReleaseTelemetry(new TelemetryClient(
            new TelemetryConfiguration
            {
                DisableTelemetry = false,
                TelemetryChannel = channel
            }));
        const string manifestId = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

        telemetry.TrackImported(manifestId, replayed: false);
        telemetry.TrackPromoted(manifestId, changed: true);
        telemetry.TrackRejected("hash mismatch");
        telemetry.TrackRolledBack(manifestId, ContentReleaseEnvironment.Staging, changed: true);

        channel.Events.Select(item => item.Name).Should().Equal(
            "content.release.import",
            "content.release.promotion",
            "content.release.rejection",
            "content.release.rollback");
        channel.Events.Should().OnlyContain(item =>
            item.Properties["component"] == "content.release");
        channel.Events[0].Properties.Should().Contain("manifestId", manifestId);
        channel.Events[1].Properties.Should().Contain("from", "staging");
        channel.Events[1].Properties.Should().Contain("to", "prod");
        channel.Events[3].Properties.Should().Contain("environment", "staging");
    }

    private sealed class RecordingTelemetryChannel : ITelemetryChannel
    {
        public List<EventTelemetry> Events { get; } = [];

        public void Send(ITelemetry item)
        {
            if (item is EventTelemetry eventTelemetry)
            {
                Events.Add(eventTelemetry);
            }
        }

        public void Flush() { }
        public bool? DeveloperMode { get; set; }
        public string? EndpointAddress { get; set; }
        public void Dispose() { }
    }
}
