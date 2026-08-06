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
    public void Emits_import_promotion_rejection_and_rollback_metrics_without_content()
    {
        var channel = new RecordingChannel();
        var configuration = new TelemetryConfiguration
        {
            DisableTelemetry = false,
            TelemetryChannel = channel
        };
        var telemetry = new ApplicationInsightsContentReleaseTelemetry(
            new TelemetryClient(configuration));
        var manifestId = $"sha256:{new string('a', 64)}";

        telemetry.TrackImported(manifestId, false, 2, 1);
        telemetry.TrackPromoted("staging", manifestId);
        telemetry.TrackRejected("public_hash_mismatch");
        telemetry.TrackRolledBack("staging", manifestId);

        channel.Events.Select(x => x.Name).Should().Equal(
            "content.release.imported",
            "content.release.promoted",
            "content.release.rejected",
            "content.release.rolled_back");
        channel.Events.Should().OnlyContain(x => x.Properties["component"] == "content.release");
        channel.Events.SelectMany(x => x.Properties.Values)
            .Should().NotContain(value => value.Contains("answer", StringComparison.OrdinalIgnoreCase));
    }

    private sealed class RecordingChannel : ITelemetryChannel
    {
        public List<EventTelemetry> Events { get; } = [];
        public bool? DeveloperMode { get; set; }
        public string? EndpointAddress { get; set; }

        public void Send(ITelemetry item)
        {
            if (item is EventTelemetry contentEvent)
            {
                Events.Add(contentEvent);
            }
        }

        public void Flush() { }
        public void Dispose() { }
    }
}
