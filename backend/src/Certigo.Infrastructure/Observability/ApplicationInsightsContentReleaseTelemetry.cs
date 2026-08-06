using Certigo.Application.Abstractions;
using Microsoft.ApplicationInsights;

namespace Certigo.Infrastructure.Observability;

public sealed class ApplicationInsightsContentReleaseTelemetry(TelemetryClient telemetryClient)
    : IContentReleaseTelemetry
{
    public void TrackImported(string manifestId, bool alreadyImported, int publicFiles, int privateFiles)
        => Track(
            alreadyImported ? "content.release.import.idempotent" : "content.release.imported",
            ("manifestId", manifestId),
            ("publicFiles", publicFiles.ToString(System.Globalization.CultureInfo.InvariantCulture)),
            ("privateFiles", privateFiles.ToString(System.Globalization.CultureInfo.InvariantCulture)));

    public void TrackPromoted(string environment, string manifestId)
        => Track(
            "content.release.promoted",
            ("environment", environment),
            ("manifestId", manifestId));

    public void TrackRolledBack(string environment, string manifestId)
        => Track(
            "content.release.rolled_back",
            ("environment", environment),
            ("manifestId", manifestId));

    public void TrackRejected(string reason)
        => Track("content.release.rejected", ("reason", reason));

    private void Track(string metric, params (string Key, string Value)[] dimensions)
    {
        var properties = dimensions.ToDictionary(
            x => x.Key,
            x => x.Value,
            StringComparer.Ordinal);
        properties["component"] = "content.release";
        telemetryClient.TrackEvent(metric, properties);
    }
}
