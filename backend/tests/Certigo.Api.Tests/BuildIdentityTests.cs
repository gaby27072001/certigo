using System.Reflection;
using Certigo.Api.Observability;
using FluentAssertions;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class BuildIdentityTests
{
    private const string Sha = "653e9112ff539bef3e937605cfc369216f2cb36f";
    private const string Timestamp = "2026-09-25T10:15:30.1234567Z";

    [Fact]
    public void Identity_normalizes_commit_and_preserves_precise_utc_build_time()
    {
        var identity = new BuildIdentity(Sha.ToUpperInvariant(), Timestamp);

        identity.CommitSha.Should().Be(Sha);
        identity.ShortCommitSha.Should().Be(Sha[..12]);
        identity.BuildTimeUtc.Should().Be(
            new DateTimeOffset(2026, 9, 25, 10, 15, 30, TimeSpan.Zero).AddTicks(1234567));
        identity.BuildTimeUtc!.Value.Offset.Should().Be(TimeSpan.Zero);
    }

    [Theory]
    [InlineData(null, null)]
    [InlineData("", "")]
    public void Missing_metadata_is_not_a_version_or_a_runtime_timestamp(string? sha, string? timestamp)
    {
        var identity = new BuildIdentity(sha, timestamp);

        identity.CommitSha.Should().BeNull();
        identity.ShortCommitSha.Should().BeNull();
        identity.BuildTimeUtc.Should().BeNull();
    }

    [Theory]
    [InlineData("main")]
    [InlineData("653e9112")]
    [InlineData("653e9112ff539bef3e937605cfc369216f2cb36g")]
    [InlineData(Sha + "\n")]
    public void Invalid_commit_is_rejected(string sha)
        => FluentActions.Invoking(() => new BuildIdentity(sha, Timestamp))
            .Should().Throw<FormatException>();

    [Theory]
    [InlineData("2026-09-25T10:15:30.1234567+02:00")]
    [InlineData("2026-09-25")]
    [InlineData("2026-02-30T10:15:30.1234567Z")]
    public void Invalid_or_non_utc_timestamp_is_rejected(string timestamp)
        => FluentActions.Invoking(() => new BuildIdentity(Sha, timestamp))
            .Should().Throw<FormatException>();

    [Fact]
    public void Identity_reads_api_assembly_metadata_even_under_the_test_host()
    {
        var identity = BuildIdentity.FromAssembly();
        var metadata = typeof(BuildIdentity).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>()
            .ToDictionary(attribute => attribute.Key, attribute => attribute.Value);

        identity.CommitSha.Should().Be(
            string.IsNullOrEmpty(metadata["Certigo.CommitSha"]) ? null : metadata["Certigo.CommitSha"]);
        identity.BuildTimeUtc.Should().NotBeNull();
        identity.BuildTimeUtc!.Value.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
            .Should().Be(metadata["Certigo.BuildTimeUtc"]);
    }

    [Theory]
    [InlineData(Sha, Sha)]
    [InlineData(null, "unknown")]
    public void Worker_telemetry_uses_build_commit_instead_of_sdk_application_version(
        string? sha, string expectedVersion)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddApplicationInsightsTelemetryWorkerService();
        services.AddSingleton(new BuildIdentity(sha, Timestamp));
        services.AddSingleton<ITelemetryInitializer, BuildIdentityTelemetryInitializer>();
        using var provider = services.BuildServiceProvider();
        var configuration = provider.GetRequiredService<TelemetryConfiguration>();
        configuration.DisableTelemetry = true;
        var client = provider.GetRequiredService<TelemetryClient>();
        var items = new Microsoft.ApplicationInsights.Channel.ITelemetry[]
        {
            new RequestTelemetry(),
            new TraceTelemetry(),
            new ExceptionTelemetry(new InvalidOperationException("test")),
            new DependencyTelemetry(),
            new MetricTelemetry("test", 1)
        };

        foreach (var item in items)
        {
            item.Context.Component.Version = "1.0.0";
            client.Initialize(item);
            item.Context.Component.Version.Should().Be(expectedVersion);
        }
    }
}
