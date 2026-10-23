using System.Security.Cryptography;
using System.Text.Json;
using Certigo.Infrastructure.Learning;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class EmbeddedPilotContentCatalogTests
{
    [Fact]
    public async Task Exact_approved_french_pilot_bytes_are_embedded_and_versioned()
    {
        var catalog = new EmbeddedPilotContentCatalog();

        var package = await catalog.GetAsync(EmbeddedPilotContentCatalog.PilotId);

        package.Should().NotBeNull();
        var bytes = package!.Json;
        var digest = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
        package.ContentDigest.Should().Be(
            "sha256:555d2cbd34f8fe7b7502d3ddfd41261248a964b0be79d07dd264e1288d4819ae");
        package.ContentDigest.Should().Be($"sha256:{digest}");
        package.LessonIds.Should().BeEquivalentTo(
            ["verify-claims", "retrieval-not-training", "stop-and-escalate"]);

        using var document = JsonDocument.Parse(bytes);
        var root = document.RootElement;
        root.GetProperty("schema").GetString().Should().Be("certigo.editorial.pilot/v1");
        root.GetProperty("locale").GetString().Should().Be("fr-FR");
        root.GetProperty("status").GetString().Should().Be("draft");
        root.GetProperty("purpose").GetString().Should().Be("learning-not-certification");
        root.GetProperty("asOf").GetString().Should().Be("2026-10-14");
        root.GetProperty("sources").GetArrayLength().Should().Be(4);
        root.GetProperty("lessons").GetArrayLength().Should().Be(3);
    }
}
