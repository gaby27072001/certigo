using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Microsoft.ApplicationInsights;

namespace Certigo.Infrastructure.Observability;

public sealed class ApplicationInsightsContentReleaseTelemetry(TelemetryClient telemetryClient)
    : IContentReleaseTelemetry
{
    public void TrackImported(string manifestId, bool replayed)
        => Track(
            "content.release.import",
            ("manifestId", manifestId),
            ("replayed", replayed.ToString().ToLowerInvariant()));

    public void TrackPromoted(string manifestId, bool changed)
        => Track(
            "content.release.promotion",
            ("manifestId", manifestId),
            ("from", "staging"),
            ("to", "prod"),
            ("changed", changed.ToString().ToLowerInvariant()));

    public void TrackRejected(string reason)
        => Track("content.release.rejection", ("reason", reason));

    public void TrackRolledBack(
        string manifestId,
        ContentReleaseEnvironment environment,
        bool changed)
        => Track(
            "content.release.rollback",
            ("manifestId", manifestId),
            ("environment", environment.ToString().ToLowerInvariant()),
            ("changed", changed.ToString().ToLowerInvariant()));

    private void Track(string eventName, params (string Key, string Value)[] dimensions)
    {
        var properties = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["component"] = "content.release"
        };
        foreach (var (key, value) in dimensions)
        {
            properties[key] = value;
        }

        telemetryClient.TrackEvent(eventName, properties);
    }
}
