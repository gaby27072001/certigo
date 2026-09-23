using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Certigo.Infrastructure.ContentContracts;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

/// <summary>
/// Opt-in pre-publication check: runs the exact backend import verification (embedded
/// schemas, C# catalog parser, graph closure, projection and public anti-leak rules)
/// against a locally built certigo-content <c>dist</c> root, before that release is
/// published to the immutable store. Skipped unless <see cref="RootVariable"/> is set.
/// </summary>
public sealed class CandidateContentPackageTests
{
    public const string RootVariable = "CERTIGO_CONTENT_CANDIDATE_ROOT";

    [CandidateContentPackageFact]
    public async Task Candidate_package_is_accepted_by_the_backend_importer()
    {
        var root = Environment.GetEnvironmentVariable(RootVariable)!;
        using var descriptor = JsonDocument.Parse(
            await File.ReadAllBytesAsync(Path.Combine(root, "release.json")));
        var releaseId = descriptor.RootElement.GetProperty("releaseId").GetString()!;
        var verifier = new ContentContractVerifier(
            new FileContentReleaseSource(root),
            new JsonSchemaContentContractValidator(),
            ContentReleaseLimits.Default);

        var verified = await verifier.VerifyReleaseAsync(releaseId);
        var projection = new RuntimeContentProjector().Project(verified.Graph);
        verifier.VerifyProjectedPublic(projection);

        verified.Descriptor.ReleaseId.Should().Be(releaseId);
        projection.Tracks.Should().NotBeEmpty();
    }
}

public sealed class CandidateContentPackageFactAttribute : FactAttribute
{
    public CandidateContentPackageFactAttribute()
    {
        var root = Environment.GetEnvironmentVariable(CandidateContentPackageTests.RootVariable);
        if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
        {
            Skip =
                $"Set {CandidateContentPackageTests.RootVariable} to a locally built certigo-content dist root.";
        }
    }
}
