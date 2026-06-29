using Microsoft.ApplicationInsights;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Observability;

public sealed class ApplicationInsightsTutorLlmTelemetry(TelemetryClient telemetryClient) : ITutorLlmTelemetry
{
    private const string SuccessMetricName = "tutor.llm.success";
    private const string ControlledFallbackMetricName = "tutor.llm.controlled_fallback";
    private const string UnexpectedErrorMetricName = "tutor.llm.unexpected_error";
    private const string RejectedResponseMetricName = "tutor.llm.rejected_response";
    private const string LatencyMetricName = "tutor.llm.latency.ms";

    public void TrackSuccess(TimeSpan latency)
    {
        TrackCount(SuccessMetricName, ("outcome", "success"));
        TrackLatency(latency, "success");
    }

    public void TrackControlledFallback(TimeSpan latency, string reason)
    {
        TrackCount(ControlledFallbackMetricName, ("outcome", "controlled_fallback"), ("reason", reason));
        TrackLatency(latency, "controlled_fallback", ("reason", reason));
    }

    public void TrackUnexpectedError(TimeSpan latency, Exception exception)
    {
        var exceptionType = exception.GetType().Name;
        TrackCount(UnexpectedErrorMetricName, ("outcome", "unexpected_error"), ("exceptionType", exceptionType));
        TrackLatency(latency, "unexpected_error", ("exceptionType", exceptionType));
    }

    public void TrackRejectedResponse(TimeSpan latency, string reason)
    {
        TrackCount(RejectedResponseMetricName, ("outcome", "rejected_response"), ("reason", reason));
        TrackLatency(latency, "rejected_response", ("reason", reason));
    }

    private void TrackCount(string metricName, params (string Key, string Value)[] dimensions)
        => telemetryClient.TrackMetric(metricName, 1, ToProperties(dimensions));

    private void TrackLatency(TimeSpan latency, string outcome, params (string Key, string Value)[] dimensions)
    {
        var allDimensions = new List<(string Key, string Value)> { ("outcome", outcome) };
        allDimensions.AddRange(dimensions);
        telemetryClient.TrackMetric(LatencyMetricName, latency.TotalMilliseconds, ToProperties(allDimensions));
    }

    private static IDictionary<string, string> ToProperties(IEnumerable<(string Key, string Value)> dimensions)
    {
        var properties = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["component"] = "tutor.llm"
        };

        foreach (var (key, value) in dimensions)
        {
            properties[key] = value;
        }

        return properties;
    }
}
