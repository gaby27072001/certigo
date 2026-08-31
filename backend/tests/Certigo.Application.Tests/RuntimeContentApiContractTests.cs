using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class RuntimeContentApiContractTests
{
    [Fact]
    public void Public_runtime_contract_is_authenticated_pinned_and_legacy_safe()
    {
        using var contract = JsonDocument.Parse(LoadContract());
        var root = contract.RootElement;

        root.GetProperty("security")[0].TryGetProperty("bearerAuth", out _).Should().BeTrue();
        root.TryGetProperty("x-certigo-feature-mode", out _).Should().BeFalse();

        var storage = root.GetProperty("x-certigo-storage");
        storage.GetProperty("access").GetString().Should().Be("external-reader-uami");
        storage.GetProperty("provisionsStorage").GetBoolean().Should().BeFalse();
        storage.GetProperty("provisionsRbac").GetBoolean().Should().BeFalse();

        var paths = root.GetProperty("paths");
        var manifest = paths.GetProperty("/content/releases/active/manifest")
            .GetProperty("get");
        manifest.GetProperty("responses").TryGetProperty("304", out _).Should().BeTrue();
        manifest.GetProperty("responses").GetProperty("304").GetProperty("headers")
            .EnumerateObject().Select(header => header.Name).Should().Contain(
                ["ETag", "Cache-Control", "X-Content-Release-Id", "X-Content-Manifest-Id"]);
        root.GetProperty("components").GetProperty("schemas")
            .GetProperty("ActivePublicManifest").GetProperty("required")
            .EnumerateArray().Select(value => value.GetString())
            .Should().Contain("releaseId");
        root.GetProperty("components").GetProperty("schemas")
            .GetProperty("ActivePublicManifest").GetProperty("properties")
            .GetProperty("schema").GetProperty("const").GetString()
            .Should().Be("certigo.content.package-manifest/v3");

        var file = paths
            .GetProperty(
                "/content/releases/{releaseId}/manifests/{publicManifestId}/files/{hash}/{path}")
            .GetProperty("get");
        file.GetProperty("x-certigo-route-template").GetString().Should()
            .EndWith("/{hash}/{*path}");
        var feature = file.GetProperty("x-certigo-feature-mode");
        feature.GetProperty("default").GetString().Should().Be("legacy");
        feature.GetProperty("enabledValue").GetString().Should().Be("versioned");
        feature.GetProperty("disabledHttpStatus").GetInt32().Should().Be(404);
        file.GetProperty("responses").EnumerateObject().Select(response => response.Name)
            .Should().Contain(["200", "304", "401", "404", "416", "503"]);
        var headers = file.GetProperty("responses").GetProperty("200")
            .GetProperty("headers");
        headers.EnumerateObject().Select(header => header.Name).Should().Contain(
            [
                "ETag",
                "Content-Length",
                "Content-Type",
                "Cache-Control",
                "Accept-Ranges",
                "X-Content-SHA256",
                "X-Content-Release-Id",
                "X-Content-Manifest-Id",
            ]);
        file.GetProperty("responses").GetProperty("304").GetProperty("headers")
            .EnumerateObject().Select(header => header.Name).Should().Contain(
                [
                    "ETag",
                    "Content-Type",
                    "Cache-Control",
                    "Accept-Ranges",
                    "X-Content-SHA256",
                    "X-Content-Release-Id",
                    "X-Content-Manifest-Id",
                ]);
        root.GetProperty("components").GetProperty("responses")
            .GetProperty("RangeNotSatisfiable").GetProperty("headers")
            .GetProperty("Cache-Control").GetProperty("$ref").GetString()
            .Should().Be("#/components/headers/NoStoreCache");
    }

    private static string LoadContract()
    {
        var relativePath = Path.Combine(
            "docs",
            "contracts",
            "runtime-content",
            "v1",
            "openapi.json");
        var directory = AppContext.BaseDirectory;
        while (directory is not null)
        {
            var candidate = Path.Combine(directory, relativePath);
            if (File.Exists(candidate))
            {
                return File.ReadAllText(candidate);
            }

            directory = Directory.GetParent(directory)?.FullName;
        }

        throw new InvalidOperationException(
            $"{relativePath} not found walking up from {AppContext.BaseDirectory}");
    }
}
