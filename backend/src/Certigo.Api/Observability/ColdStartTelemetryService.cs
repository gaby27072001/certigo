using Microsoft.ApplicationInsights;
using Microsoft.Extensions.Hosting;

namespace Certigo.Api.Observability;

internal sealed class ColdStartTelemetryService(TelemetryClient telemetryClient) : IHostedService
{
    internal const string MetricName = "functions.cold_start";
    private int started;

    public Task StartAsync(CancellationToken cancellationToken)
    {
        if (Interlocked.Exchange(ref started, 1) == 0)
        {
            telemetryClient.TrackMetric(
                MetricName,
                1,
                new Dictionary<string, string>
                {
                    ["component"] = "functions.host",
                    ["runtime"] = "dotnet-isolated"
                });
        }

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
