using FluentAssertions;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using Microlingo.Infrastructure.Observability;
using Xunit;

namespace Microlingo.Infrastructure.Tests;

public sealed class ApplicationInsightsTutorLlmTelemetryTests
{
    [Fact]
    public void TrackSuccess_emits_success_and_latency_metrics()
    {
        var channel = new RecordingTelemetryChannel();
        var telemetry = CreateTelemetry(channel);

        telemetry.TrackSuccess(TimeSpan.FromMilliseconds(123));

        channel.Metrics.Should().ContainSingle(m => m.Name == "tutor.llm.success" && m.Sum == 1);
        channel.Metrics.Should().ContainSingle(m =>
            m.Name == "tutor.llm.latency.ms"
            && m.Sum == 123
            && m.Properties["outcome"] == "success");
    }

    [Fact]
    public void TrackControlledFallback_emits_reason_and_latency()
    {
        var channel = new RecordingTelemetryChannel();
        var telemetry = CreateTelemetry(channel);

        telemetry.TrackControlledFallback(TimeSpan.FromMilliseconds(87), "provider_unavailable");

        channel.Metrics.Should().ContainSingle(m =>
            m.Name == "tutor.llm.controlled_fallback"
            && m.Properties["reason"] == "provider_unavailable");
        channel.Metrics.Should().ContainSingle(m =>
            m.Name == "tutor.llm.latency.ms"
            && m.Properties["outcome"] == "controlled_fallback"
            && m.Properties["reason"] == "provider_unavailable");
    }

    [Fact]
    public void TrackUnexpectedError_emits_exception_type_and_latency()
    {
        var channel = new RecordingTelemetryChannel();
        var telemetry = CreateTelemetry(channel);

        telemetry.TrackUnexpectedError(TimeSpan.FromMilliseconds(45), new InvalidOperationException("boom"));

        channel.Metrics.Should().ContainSingle(m =>
            m.Name == "tutor.llm.unexpected_error"
            && m.Properties["exceptionType"] == nameof(InvalidOperationException));
        channel.Metrics.Should().ContainSingle(m =>
            m.Name == "tutor.llm.latency.ms"
            && m.Properties["outcome"] == "unexpected_error"
            && m.Properties["exceptionType"] == nameof(InvalidOperationException));
    }

    private static ApplicationInsightsTutorLlmTelemetry CreateTelemetry(RecordingTelemetryChannel channel)
    {
        var configuration = new TelemetryConfiguration
        {
            DisableTelemetry = false,
            TelemetryChannel = channel
        };

        return new ApplicationInsightsTutorLlmTelemetry(new TelemetryClient(configuration));
    }

    private sealed class RecordingTelemetryChannel : ITelemetryChannel
    {
        public List<MetricTelemetry> Metrics { get; } = new();

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
