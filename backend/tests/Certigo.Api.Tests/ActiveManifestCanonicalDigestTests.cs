using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Certigo.Api.Auth;
using Certigo.Api.Functions;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

/// The published package manifest is canonicalised as sorted-key compact JSON with
/// absent optional keys omitted, and `manifestId`/`rootHash` are the SHA-256 of that
/// exact form. Mobile clients re-derive the digest from the bytes this API returns and
/// reject the release on mismatch, so our serialization must reproduce the canonical
/// form byte for byte.
///
/// These tests are self-checking: the expected digest is built independently from a
/// canonical model that omits null-valued optional keys by construction, then compared
/// against a digest recomputed from the real HTTP response body. They therefore go red
/// for any property that starts emitting `null`, on any shape of data, without needing
/// a captured fixture to be refreshed.
public sealed class ActiveManifestCanonicalDigestTests
{
    private const string ReleaseId =
        "sha256:6094410ae57637d55681fdeec3eae50fbfd69ba953741d069c95a478bee73f7f";

    [Fact]
    public async Task Active_manifest_response_reproduces_the_canonical_digest()
    {
        var manifest = CanonicalManifest();
        var function = new ContentReleaseFunctions(
            new StubReleaseService(manifest),
            new ContentAdminAuthorization("Content.Release.Admin", allowDevIdentity: false));
        var context = TestFunctionContext.Authenticated();
        var request = Request(context);

        var response = await function.GetActivePublicManifest(request, context);
        var body = await response.ReadBodyAsStringAsync();

        DigestOfServedBody(body).Should().Be(
            manifest.RootHash,
            "the client recomputes this digest from the response bytes and rejects the "
            + "release when it does not match the declared rootHash");
    }

    [Fact]
    public async Task Active_manifest_response_never_emits_a_null_valued_key()
    {
        var function = new ContentReleaseFunctions(
            new StubReleaseService(CanonicalManifest()),
            new ContentAdminAuthorization("Content.Release.Admin", allowDevIdentity: false));
        var context = TestFunctionContext.Authenticated();

        var response = await function.GetActivePublicManifest(Request(context), context);
        var body = await response.ReadBodyAsStringAsync();

        NullValuedKeys(JsonNode.Parse(body)!).Should().BeEmpty(
            "a null-valued key is absent from the canonical form the digest was computed "
            + "over, so emitting one breaks verification for every client");
    }

    /// Guards the guard: if the manifest under test carried no optional-key variation,
    /// the digest assertion above could pass without exercising null omission at all.
    [Fact]
    public void Fixture_mixes_present_and_absent_optional_keys()
    {
        var files = CanonicalManifest().Files;

        files.Should().Contain(file => file.Provider == null);
        files.Should().Contain(file => file.Provider != null);
    }

    private static TestHttpRequestData Request(TestFunctionContext context)
        => new(
            context,
            "GET",
            "https://certigo.test/api/content/releases/active/manifest");

    /// Builds a manifest whose `rootHash` is the SHA-256 of the canonical form, derived
    /// here by explicit construction: optional keys are added only when non-null. This
    /// never observes the serializer, so agreement with the response body is evidence,
    /// not tautology.
    private static ContentPackageManifest CanonicalManifest()
    {
        ContentPackageFile[] files =
        [
            new(
                "certification-catalog",
                "catalog/certifications.json",
                "certificationCatalog",
                new string('a', 64),
                123),
            new(
                "aws.sap-c02.domain-1.tagging.005",
                "questions/aws/sap-c02-005.json",
                "question",
                new string('b', 64),
                4096,
                Provider: "aws",
                Certification: "aws:sap-c02",
                BlueprintVersion: "2026-08-17",
                Objective: "domain-1"),
        ];

        var body = new JsonObject
        {
            ["schema"] = ContentReleaseContracts.PackageManifestV3,
            ["channel"] = "public",
            ["artifact"] = "public",
            ["algorithm"] = "sha256",
            ["serialization"] = "json-sorted-keys-compact-utf8-lf",
            ["fileCount"] = files.Length,
            ["files"] = new JsonArray(files.Select(CanonicalFile).ToArray<JsonNode?>()),
        };

        var rootHash = Sha256Hex(Canonicalise(body));
        return new ContentPackageManifest(
            ContentReleaseContracts.PackageManifestV3,
            "public",
            "public",
            "sha256",
            "json-sorted-keys-compact-utf8-lf",
            files.Length,
            files,
            $"sha256:{rootHash}",
            rootHash);
    }

    private static JsonObject CanonicalFile(ContentPackageFile file)
    {
        var node = new JsonObject
        {
            ["id"] = file.Id,
            ["path"] = file.Path,
            ["hash"] = file.Hash,
            ["size"] = file.Size,
        };
        AddWhenPresent(node, "resourceType", file.ResourceType);
        AddWhenPresent(node, "provider", file.Provider);
        AddWhenPresent(node, "certification", file.Certification);
        AddWhenPresent(node, "blueprintVersion", file.BlueprintVersion);
        AddWhenPresent(node, "objective", file.Objective);
        return node;
    }

    private static void AddWhenPresent(JsonObject node, string key, string? value)
    {
        if (value is not null)
        {
            node[key] = value;
        }
    }

    /// Mirrors the client: drop the identity fields, canonicalise, hash.
    private static string DigestOfServedBody(string body)
    {
        var served = JsonNode.Parse(body)!.AsObject();
        var digestBody = new JsonObject();
        foreach (var property in served)
        {
            if (property.Key is "manifestId" or "rootHash" or "releaseId")
            {
                continue;
            }

            digestBody[property.Key] = property.Value?.DeepClone();
        }

        return Sha256Hex(Canonicalise(digestBody));
    }

    private static IReadOnlyList<string> NullValuedKeys(JsonNode node, string path = "$")
    {
        var found = new List<string>();
        switch (node)
        {
            case JsonObject entries:
                foreach (var property in entries)
                {
                    if (property.Value is null || property.Value.GetValueKind() == JsonValueKind.Null)
                    {
                        found.Add($"{path}.{property.Key}");
                        continue;
                    }

                    found.AddRange(NullValuedKeys(property.Value, $"{path}.{property.Key}"));
                }

                break;
            case JsonArray items:
                for (var index = 0; index < items.Count; index++)
                {
                    if (items[index] is { } item)
                    {
                        found.AddRange(NullValuedKeys(item, $"{path}[{index}]"));
                    }
                }

                break;
        }

        return found;
    }

    /// Sorted-key compact JSON, matching `json-sorted-keys-compact-utf8-lf`.
    private static string Canonicalise(JsonNode? node)
    {
        switch (node)
        {
            case JsonObject entries:
                var sorted = entries
                    .OrderBy(property => property.Key, StringComparer.Ordinal)
                    .Select(property =>
                        $"{JsonSerializer.Serialize(property.Key)}:{Canonicalise(property.Value)}");
                return $"{{{string.Join(",", sorted)}}}";
            case JsonArray items:
                return $"[{string.Join(",", items.Select(Canonicalise))}]";
            case null:
                return "null";
            default:
                return node.ToJsonString();
        }
    }

    private static string Sha256Hex(string value)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private sealed class StubReleaseService(ContentPackageManifest manifest) : IContentReleaseService
    {
        public Task<ContentImportResult> ImportAsync(
            string releaseId,
            string actorId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer?> GetPointerAsync(
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer> PromoteAsync(
            string releaseId,
            string expectedETag,
            string actorId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer> RollbackAsync(
            string expectedETag,
            string actorId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult<ActivePublicManifestResult?>(
                new ActivePublicManifestResult(manifest, ReleaseId, manifest.ManifestId));
    }
}
