using System.Globalization;
using System.Reflection;
using System.Text.RegularExpressions;

namespace Certigo.Api.Observability;

public sealed class BuildIdentity
{
    public string? CommitSha { get; }
    public string? ShortCommitSha => CommitSha?[..12];
    public DateTimeOffset? BuildTimeUtc { get; }

    internal BuildIdentity(string? commitSha, string? buildTimeUtc)
    {
        if (!string.IsNullOrEmpty(commitSha))
        {
            if (!Regex.IsMatch(commitSha, @"\A[0-9a-fA-F]{40}\z", RegexOptions.CultureInvariant))
            {
                throw new FormatException("The compiled build identity contains an invalid commit SHA.");
            }

            CommitSha = commitSha.ToLowerInvariant();
        }

        if (!string.IsNullOrEmpty(buildTimeUtc))
        {
            BuildTimeUtc = DateTimeOffset.ParseExact(
                buildTimeUtc,
                "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);
        }
    }

    public static BuildIdentity FromAssembly()
    {
        // Never consult deployment settings, the entry assembly (test host), or the runtime clock.
        var metadata = typeof(BuildIdentity).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>();
        return new BuildIdentity(
            metadata.SingleOrDefault(attribute => attribute.Key == "Certigo.CommitSha")?.Value,
            metadata.SingleOrDefault(attribute => attribute.Key == "Certigo.BuildTimeUtc")?.Value);
    }
}
