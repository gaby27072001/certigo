using Certigo.Api.Observability;
using FluentAssertions;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ColdStartTelemetryServiceTests
{
    [Fact]
    public async Task StartAsync_emits_one_low_cardinality_metric_per_process()
    {
        var channel = new RecordingTelemetryChannel();
        var configuration = new TelemetryConfiguration
        {
            DisableTelemetry = false,
            TelemetryChannel = channel
        };
        var service = new ColdStartTelemetryService(new TelemetryClient(configuration));

        await service.StartAsync(CancellationToken.None);
        await service.StartAsync(CancellationToken.None);

        var metric = channel.Metrics.Should().ContainSingle().Subject;
        metric.Name.Should().Be(ColdStartTelemetryService.MetricName);
        metric.Sum.Should().Be(1);
        metric.Properties.Should().BeEquivalentTo(new Dictionary<string, string>
        {
            ["component"] = "functions.host",
            ["runtime"] = "dotnet-isolated"
        });
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
