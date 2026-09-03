using Certigo.Application.Abstractions;
using Microsoft.ApplicationInsights;

namespace Certigo.Infrastructure.Observability;

public sealed class ApplicationInsightsContentReleaseTelemetry(TelemetryClient telemetry)
    : IContentReleaseTelemetry
{
    public void TrackImport(string releaseId, bool alreadyImported, TimeSpan duration)
        => telemetry.TrackEvent(
            "content.release.import",
            new Dictionary<string, string>
            {
                ["releaseId"] = releaseId,
                ["alreadyImported"] = alreadyImported.ToString(),
            },
            new Dictionary<string, double> { ["durationMs"] = duration.TotalMilliseconds });

    public void TrackRejection(string releaseId, string reason, TimeSpan duration)
        => telemetry.TrackEvent(
            "content.release.rejected",
            new Dictionary<string, string>
            {
                ["releaseId"] = releaseId,
                ["reason"] = reason,
            },
            new Dictionary<string, double> { ["durationMs"] = duration.TotalMilliseconds });

    public void TrackPromotion(string releaseId, string? previousReleaseId)
        => telemetry.TrackEvent(
            "content.release.promoted",
            new Dictionary<string, string>
            {
                ["releaseId"] = releaseId,
                ["previousReleaseId"] = previousReleaseId ?? string.Empty,
            });

    public void TrackRollback(string releaseId, string rolledBackFromReleaseId)
        => telemetry.TrackEvent(
            "content.release.rolled_back",
            new Dictionary<string, string>
            {
                ["releaseId"] = releaseId,
                ["rolledBackFromReleaseId"] = rolledBackFromReleaseId,
            });
}
