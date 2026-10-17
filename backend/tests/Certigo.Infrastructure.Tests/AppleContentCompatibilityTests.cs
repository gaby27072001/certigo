using System.Security.Cryptography;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Infrastructure.ContentContracts;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class AppleContentCompatibilityTests
{
    [Theory]
    [InlineData("supported/question-v3.json")]
    [InlineData("supported/question-v4-mcq.json")]
    [InlineData("capability-probes/question-v4-spot-the-issue.json")]
    public async Task Real_release_reader_accepts_producer_file_bytes_before_private_boundary(string file)
    {
        var source = new PublicVectorSource(file, packageTermination: "\n");
        var verifier = new ContentContractVerifier(
            source, new JsonSchemaContentContractValidator(), ContentReleaseLimits.Default);

        var action = () => verifier.VerifyReleaseAsync(source.ReleaseId);

        await action.Should().ThrowAsync<PrivateBoundaryException>(
            "this public-only test stops before requesting any private package");
        source.PublicFileReads.Should().Be(1);
        source.PrivateManifestReads.Should().Be(1,
            "the real reader must finish public size/hash/schema/identity checks first");
    }

    [Theory]
    [InlineData("supported/question-v3.json", "")]
    [InlineData("supported/question-v3.json", "\r\n")]
    [InlineData("supported/question-v4-mcq.json", "")]
    [InlineData("supported/question-v4-mcq.json", "\r\n")]
    [InlineData("capability-probes/question-v4-spot-the-issue.json", "")]
    [InlineData("capability-probes/question-v4-spot-the-issue.json", "\r\n")]
    public async Task Real_release_reader_rejects_body_or_crlf_as_producer_package_file(
        string file, string packageTermination)
    {
        var source = new PublicVectorSource(file, packageTermination);
        var verifier = new ContentContractVerifier(
            source, new JsonSchemaContentContractValidator(), ContentReleaseLimits.Default);

        var action = () => verifier.VerifyReleaseAsync(source.ReleaseId);

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*bytes; expected*");
        source.PrivateManifestReads.Should().Be(0);
    }

    [Theory]
    [InlineData("supported/question-v3.json")]
    [InlineData("supported/question-v4-mcq.json")]
    [InlineData("capability-probes/question-v4-spot-the-issue.json")]
    public void Embedded_backend_schema_accepts_each_shared_public_vector(string file)
    {
        var payload = ReadObject(file);
        var expected = Vector(file);

        expected["contract"]!.GetValue<string>().Should().Be("valid");
        payload["schemaVersion"]!.GetValue<string>()
            .Should().Be(expected["schemaVersion"]!.GetValue<string>());
        new JsonSchemaContentContractValidator()
            .Validate("question.schema.json", Element(payload));
    }

    [Theory]
    [InlineData("supported/question-v3.json")]
    [InlineData("supported/question-v4-mcq.json")]
    [InlineData("capability-probes/question-v4-spot-the-issue.json")]
    public void Csharp_utf8_body_and_lf_file_match_producer_digest_vectors(string file)
    {
        var body = CanonicalBytes(Element(ReadObject(file)));
        var digests = Vector(file)["payloadDigests"]!.AsObject();

        AssertDigest(body, digests["canonicalBody"]!.AsObject());
        var packageFile = body.Concat(new byte[] { (byte)'\n' }).ToArray();
        AssertDigest(packageFile, digests["packageFile"]!.AsObject());

        SHA256.HashData(body).Should().NotEqual(SHA256.HashData(packageFile),
            "body identity excludes LF while package-file identity includes exactly one LF");
        var crlfFile = body.Concat(new byte[] { (byte)'\r', (byte)'\n' }).ToArray();
        Convert.ToHexString(SHA256.HashData(crlfFile)).ToLowerInvariant()
            .Should().NotBe(digests["packageFile"]!["sha256"]!.GetValue<string>());
    }

    [Theory]
    [InlineData("supported/question-v3.json")]
    [InlineData("supported/question-v4-mcq.json")]
    [InlineData("capability-probes/question-v4-spot-the-issue.json")]
    public void Embedded_backend_schema_rejects_shared_malformed_mutations(string file)
    {
        foreach (var negative in ReadObject("expected-outcomes.json")["negativeCases"]!.AsArray())
        {
            var control = negative!.AsObject();
            var mutation = control["mutation"]!.AsObject();
            var property = (mutation["addProperty"] ?? mutation["addForbiddenProperty"])!
                .GetValue<string>();
            var payload = ReadObject(file);
            payload[property] = new JsonArray("not-an-answer");
            control["schemaValid"]!.GetValue<bool>().Should().BeFalse();

            var action = () => new JsonSchemaContentContractValidator()
                .Validate("question.schema.json", Element(payload));

            action.Should().Throw<ContentReleaseValidationException>(
                $"producer negative case {control["id"]!.GetValue<string>()} must also fail in C#");
        }
    }

    [Fact]
    public void Unsupported_apple_capability_is_not_a_malformed_backend_question()
    {
        const string file = "capability-probes/question-v4-spot-the-issue.json";
        var payload = ReadObject(file);
        var expected = Vector(file);
        var profile = ReadObject("expected-outcomes.json")["capabilityProfile"]!.AsObject();

        expected["client"]!.GetValue<string>().Should().Be("unsupported-capability");
        expected["notMalformed"]!.GetValue<bool>().Should().BeTrue();
        expected["profile"]!.GetValue<string>().Should().Be(profile["id"]!.GetValue<string>());
        var itemType = payload["itemType"]!.GetValue<string>();
        profile["supportedItemTypes"]!.AsArray().Select(item => item!.GetValue<string>())
            .Should().NotContain(itemType);
        expected["requiredCapability"]!.GetValue<string>().Should().Be($"itemType:{itemType}");
        new JsonSchemaContentContractValidator()
            .Validate("question.schema.json", Element(payload));
    }

    private static void AssertDigest(byte[] bytes, JsonObject expected)
    {
        bytes.Length.Should().Be(expected["size"]!.GetValue<int>());
        Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant()
            .Should().Be(expected["sha256"]!.GetValue<string>());
    }

    private static JsonObject Vector(string file)
        => ReadObject("expected-outcomes.json")["vectors"]!.AsArray()
            .Single(vector => vector!["file"]!.GetValue<string>() == file)!.AsObject();

    private static JsonElement Element(JsonObject value)
    {
        using var document = JsonDocument.Parse(value.ToJsonString());
        return document.RootElement.Clone();
    }

    private static JsonObject ReadObject(string file)
        => JsonNode.Parse(File.ReadAllBytes(Path.Combine(
            FixtureRoot(), file.Replace('/', Path.DirectorySeparatorChar))))!.AsObject();

    private static string FixtureRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Certigo.sln")))
        {
            directory = directory.Parent;
        }

        directory.Should().NotBeNull("tests must locate backend\\Certigo.sln");
        return Path.Combine(
            directory!.FullName, "tests", "Certigo.Infrastructure.Tests", "Fixtures", "apple-compat", "v1");
    }

    private static byte[] CanonicalBytes(JsonElement value)
    {
        using var stream = new MemoryStream();
        using var writer = new Utf8JsonWriter(stream, new JsonWriterOptions
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        });
        WriteSorted(writer, value);
        writer.Flush();
        return stream.ToArray();
    }

    private static void WriteSorted(Utf8JsonWriter writer, JsonElement value)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (var property in value.EnumerateObject()
                             .OrderBy(property => property.Name, StringComparer.Ordinal))
                {
                    writer.WritePropertyName(property.Name);
                    WriteSorted(writer, property.Value);
                }

                writer.WriteEndObject();
                break;
            case JsonValueKind.Array:
                writer.WriteStartArray();
                foreach (var item in value.EnumerateArray())
                {
                    WriteSorted(writer, item);
                }

                writer.WriteEndArray();
                break;
            default:
                value.WriteTo(writer);
                break;
        }
    }

    private sealed class PrivateBoundaryException : Exception;

    private sealed class PublicVectorSource : IContentReleaseSource
    {
        private const string Path = "questions/vector.json";
        private readonly byte[] _payload;
        private readonly byte[] _manifest;
        private readonly byte[] _descriptor;

        public PublicVectorSource(string file, string packageTermination)
        {
            var question = ReadObject(file);
            var digests = Vector(file)["payloadDigests"]!["packageFile"]!;
            _payload = CanonicalBytes(Element(question))
                .Concat(System.Text.Encoding.UTF8.GetBytes(packageTermination)).ToArray();
            var manifest = new JsonObject
            {
                ["schema"] = ContentReleaseContracts.PackageManifestV3,
                ["channel"] = "public",
                ["artifact"] = "public",
                ["algorithm"] = "sha256",
                ["serialization"] = "json-sorted-keys-compact-utf8-lf",
                ["fileCount"] = 1,
                ["files"] = new JsonArray(new JsonObject
                {
                    ["id"] = question["id"]!.GetValue<string>(),
                    ["path"] = Path,
                    ["resourceType"] = "question",
                    ["hash"] = digests["sha256"]!.GetValue<string>(),
                    ["size"] = digests["size"]!.GetValue<int>(),
                }),
            };
            var rootHash = Digest(CanonicalBytes(Element(manifest)));
            manifest["manifestId"] = $"sha256:{rootHash}";
            manifest["rootHash"] = rootHash;
            _manifest = CanonicalBytes(Element(manifest));
            var descriptor = new JsonObject
            {
                ["schema"] = ContentReleaseContracts.ReleaseV1,
                ["algorithm"] = "sha256",
                ["canonicalization"] = "json-sorted-keys-compact-utf8",
                ["publicManifestId"] = $"sha256:{rootHash}",
                ["privateManifestId"] = $"sha256:{new string('0', 64)}",
            };
            ReleaseId = $"sha256:{Digest(CanonicalBytes(Element(descriptor)))}";
            descriptor["releaseId"] = ReleaseId;
            _descriptor = CanonicalBytes(Element(descriptor));
        }

        public string ReleaseId { get; }
        public int PublicFileReads { get; private set; }
        public int PrivateManifestReads { get; private set; }

        public Task<ContentBlobObject> ReadReleaseAsync(
            string releaseId, CancellationToken cancellationToken = default)
            => Task.FromResult(Blob("release.json", _descriptor));

        public Task<ContentBlobObject> ReadManifestAsync(
            ContentArtifact artifact, string manifestId, CancellationToken cancellationToken = default)
        {
            if (artifact == ContentArtifact.Private)
            {
                PrivateManifestReads++;
                throw new PrivateBoundaryException();
            }

            return Task.FromResult(Blob("manifest.json", _manifest));
        }

        public Task<ContentBlobObject> ReadFileAsync(
            ContentArtifact artifact, string manifestId, string path,
            CancellationToken cancellationToken = default)
        {
            artifact.Should().Be(ContentArtifact.Public);
            path.Should().Be(Path);
            PublicFileReads++;
            return Task.FromResult(Blob(Path, _payload));
        }

        public Task<IReadOnlyList<string>> ListFilesAsync(
            ContentArtifact artifact, string manifestId, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<string>>([Path]);

        private static ContentBlobObject Blob(string path, byte[] bytes)
            => new(path, "synthetic-version", "\"synthetic-etag\"", true, bytes);

        private static string Digest(byte[] bytes)
            => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    }
}
