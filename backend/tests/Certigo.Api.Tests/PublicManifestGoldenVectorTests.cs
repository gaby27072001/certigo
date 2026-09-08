using System.Text;
using System.Text.Json;
using Certigo.Application.Abstractions;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

/// Pins the wire format of the public package manifest to a golden vector that is
/// also read by `packages/data/test/public_manifest_golden_test.dart`, where the real
/// mobile client parser verifies it.
///
/// One committed artefact, two languages: this side fails if .NET stops reproducing
/// the bytes; the Dart side fails if the client stops accepting them. Neither test can
/// pass by construction, because neither owns both halves of the contract.
public sealed class PublicManifestGoldenVectorTests
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    [Fact]
    public void Serializer_reproduces_the_golden_wire_bytes()
    {
        var golden = ReadGolden();
        var manifest = JsonSerializer.Deserialize<ContentPackageManifest>(golden, Options)!;

        JsonSerializer.Serialize(manifest, Options).Should().Be(
            golden,
            "the mobile client re-derives the manifest digest from these exact bytes, so "
            + "any change to the emitted shape invalidates every release");
    }

    [Fact]
    public void Golden_vector_covers_present_and_absent_optional_keys()
    {
        var manifest = JsonSerializer.Deserialize<ContentPackageManifest>(ReadGolden(), Options)!;

        manifest.Files.Should().Contain(file => file.Objective == null);
        manifest.Files.Should().Contain(file => file.Objective != null);
    }

    internal static string ReadGolden()
        => File.ReadAllText(GoldenPath(), new UTF8Encoding(false));

    private static string GoldenPath()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(
                directory.FullName,
                "docs",
                "contracts",
                "runtime-content",
                "v1",
                "public-manifest.golden.json");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException("public-manifest.golden.json was not found.");
    }
}
