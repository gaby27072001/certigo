using System;
using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.Build.Framework;

// Run by the SDK's RoslynCodeTaskFactory, not compiled into the application.
public sealed class CertigoBuildIdentityTask : Microsoft.Build.Utilities.Task
{
    public string SourceRevisionId { get; set; } = "";
    public string BuildTimeUtc { get; set; } = "";
    public string ContinuousIntegrationBuild { get; set; } = "";
    public string GitHubActions { get; set; } = "";
    public string GitHubWorkflow { get; set; } = "";
    public string GitHubEventName { get; set; } = "";
    public string GitHubRef { get; set; } = "";
    public string GitHubSha { get; set; } = "";

    [Output]
    public string CommitSha { get; set; } = "";

    [Output]
    public string ValidatedBuildTimeUtc { get; set; } = "";

    public override bool Execute()
    {
        if (!string.IsNullOrEmpty(SourceRevisionId)
            && !Regex.IsMatch(SourceRevisionId, @"\A[0-9a-fA-F]{40}\z"))
        {
            Log.LogError("SourceRevisionId must be a full Git commit SHA.");
            return false;
        }

        if (IsTrue(ContinuousIntegrationBuild) && string.IsNullOrEmpty(SourceRevisionId))
        {
            Log.LogError("A CI build requires source commit metadata. Build from the source checkout or supply SourceRevisionId for an exported source tree.");
            return false;
        }

        // pull_request_target builds the PR head, but GITHUB_SHA is the trusted base.
        if (IsTrue(GitHubActions) && GitHubWorkflow == "cd-backend"
            && GitHubEventName == "push" && GitHubRef == "refs/heads/main"
            && (string.IsNullOrEmpty(SourceRevisionId)
                || !string.Equals(SourceRevisionId, GitHubSha, StringComparison.OrdinalIgnoreCase)))
        {
            Log.LogError("The compiled source revision must match GITHUB_SHA, the release provenance commit.");
            return false;
        }

        const string format = "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'";
        var timestamp = string.IsNullOrEmpty(BuildTimeUtc)
            ? DateTimeOffset.UtcNow.ToString(format, CultureInfo.InvariantCulture)
            : BuildTimeUtc;
        DateTimeOffset parsed;
        if (!DateTimeOffset.TryParseExact(timestamp, format, CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out parsed))
        {
            Log.LogError("CertigoBuildTimeUtc must be a valid build timestamp in UTC (yyyy-MM-ddTHH:mm:ss.fffffffZ).");
            return false;
        }

        CommitSha = (SourceRevisionId ?? "").ToLowerInvariant();
        ValidatedBuildTimeUtc = timestamp;
        return true;
    }

    private static bool IsTrue(string value)
        => string.Equals(value, "true", StringComparison.OrdinalIgnoreCase);
}
