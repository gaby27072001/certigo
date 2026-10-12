using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class BuildIdentityBuildTests
{
    private const string Sha = "653e9112ff539bef3e937605cfc369216f2cb36f";
    private const string OtherSha = "753e9112ff539bef3e937605cfc369216f2cb36f";
    private const string Timestamp = "2026-09-25T10:15:30.1234567Z";

    [Fact]
    public async Task Release_metadata_matches_source_provenance()
    {
        var result = await GenerateMetadata();

        result.ExitCode.Should().Be(0, result.Output);
        using var document = JsonDocument.Parse(result.Output);
        var metadata = document.RootElement.GetProperty("Items").GetProperty("AssemblyMetadata")
            .EnumerateArray().ToDictionary(
                item => item.GetProperty("Identity").GetString()!,
                item => item.GetProperty("Value").GetString());
        metadata["Certigo.CommitSha"].Should().Be(Sha);
        metadata["Certigo.BuildTimeUtc"].Should().Be(Timestamp);
    }

    [Fact]
    public async Task Default_timestamp_is_captured_during_the_build()
    {
        var before = DateTimeOffset.UtcNow;
        var result = await GenerateMetadata(("CertigoBuildTimeUtc", null));
        var after = DateTimeOffset.UtcNow;

        result.ExitCode.Should().Be(0, result.Output);
        using var document = JsonDocument.Parse(result.Output);
        var timestamp = document.RootElement.GetProperty("Items").GetProperty("AssemblyMetadata")
            .EnumerateArray().Single(item => item.GetProperty("Identity").GetString() == "Certigo.BuildTimeUtc")
            .GetProperty("Value").GetString();
        DateTimeOffset.ParseExact(timestamp!, "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
                CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal)
            .Should().BeOnOrAfter(before).And.BeOnOrBefore(after);
    }

    [Fact]
    public async Task Release_rejects_a_commit_different_from_the_source_run()
    {
        var result = await GenerateMetadata(("GITHUB_SHA", OtherSha));

        result.ExitCode.Should().NotBe(0);
        result.Output.Should().Contain("must match GITHUB_SHA");
    }

    [Fact]
    public async Task Pull_request_target_uses_the_built_head_not_the_trusted_base()
    {
        var result = await GenerateMetadata(
            ("GITHUB_WORKFLOW", "ci-backend"),
            ("GITHUB_EVENT_NAME", "pull_request_target"),
            ("GITHUB_SHA", OtherSha));

        result.ExitCode.Should().Be(0, result.Output);
        result.Output.Should().Contain(Sha).And.NotContain(OtherSha);
    }

    [Fact]
    public async Task Exported_local_source_can_build_without_a_commit()
    {
        var result = await GenerateMetadata(
            ("ContinuousIntegrationBuild", "false"),
            ("GITHUB_ACTIONS", "false"),
            ("SourceRevisionId", ""));

        result.ExitCode.Should().Be(0, result.Output);
        using var document = JsonDocument.Parse(result.Output);
        var commit = document.RootElement.GetProperty("Items").GetProperty("AssemblyMetadata")
            .EnumerateArray().Single(item => item.GetProperty("Identity").GetString() == "Certigo.CommitSha");
        commit.GetProperty("Value").GetString().Should().BeEmpty();
    }

    [Fact]
    public async Task Ci_refuses_exported_source_without_provenance()
    {
        var result = await GenerateMetadata(("SourceRevisionId", ""));

        result.ExitCode.Should().NotBe(0);
        result.Output.Should().Contain("A CI build requires source commit metadata");
    }

    [Theory]
    [InlineData("SourceRevisionId", "main")]
    [InlineData("CertigoBuildTimeUtc", "2026-09-25T10:15:30.1234567+02:00")]
    [InlineData("CertigoBuildTimeUtc", "2026-02-30T10:15:30.1234567Z")]
    public async Task Invalid_build_inputs_fail_before_compilation(string property, string value)
    {
        var result = await GenerateMetadata((property, value));

        result.ExitCode.Should().NotBe(0);
    }

    private static async Task<(int ExitCode, string Output)> GenerateMetadata(
        params (string Property, string? Value)[] overrides)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Certigo.sln")))
        {
            directory = directory.Parent;
        }

        directory.Should().NotBeNull("these build-contract tests run from the backend source tree");
        var properties = new Dictionary<string, string>
        {
            ["EnableSourceControlManagerQueries"] = "false",
            ["SourceRevisionId"] = Sha,
            ["CertigoBuildTimeUtc"] = Timestamp,
            ["ContinuousIntegrationBuild"] = "true",
            ["GITHUB_ACTIONS"] = "true",
            ["GITHUB_WORKFLOW"] = "cd-backend",
            ["GITHUB_EVENT_NAME"] = "push",
            ["GITHUB_REF"] = "refs/heads/main",
            ["GITHUB_SHA"] = Sha
        };
        foreach (var (property, value) in overrides)
        {
            if (value is null)
            {
                properties.Remove(property);
            }
            else
            {
                properties[property] = value;
            }
        }

        var start = new ProcessStartInfo("dotnet")
        {
            WorkingDirectory = directory!.FullName,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };
        start.Environment.Remove("CertigoBuildTimeUtc");
        foreach (var argument in new[]
        {
            "msbuild", Path.Combine("src", "Certigo.Api", "Certigo.Api.csproj"),
            "-target:GenerateCertigoBuildIdentity", "-getItem:AssemblyMetadata", "-verbosity:quiet", "-nologo"
        })
        {
            start.ArgumentList.Add(argument);
        }
        foreach (var (property, value) in properties)
        {
            start.ArgumentList.Add($"-p:{property}={value}");
        }

        using var process = Process.Start(start)!;
        var output = process.StandardOutput.ReadToEndAsync();
        var error = process.StandardError.ReadToEndAsync();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(60));
        try
        {
            await process.WaitForExitAsync(timeout.Token);
        }
        finally
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }

        return (process.ExitCode, await output + await error);
    }
}
