using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

public static class ContentPackageIntegrity
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static void Validate(ImportContentReleaseRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (!string.Equals(
                request.ContractVersion,
                ContentReleaseContracts.ImportContractVersion,
                StringComparison.Ordinal))
        {
            throw new ContentReleaseValidationException(
                $"Unsupported import contract '{request.ContractVersion}'.");
        }

        EnsureNoAdditionalProperties(request.AdditionalProperties, "import request");

        ValidatePackage(request.Public, "public", "public", "questions/");
        ValidatePackage(request.Private, "answerKey", "private", "solutions/");

        var publicIds = request.Public.Manifest.Files
            .Select(file => file.Id)
            .ToHashSet(StringComparer.Ordinal);
        var privateIds = request.Private.Manifest.Files
            .Select(file => file.Id)
            .ToHashSet(StringComparer.Ordinal);
        if (!publicIds.SetEquals(privateIds))
        {
            throw new ContentReleaseValidationException(
                "Public questions and private solutions must contain the same item ids.");
        }
    }

    public static byte[] Canonicalize(JsonElement value)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions
               {
                   Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
                   Indented = false
               }))
        {
            WriteCanonical(writer, value);
        }

        stream.WriteByte((byte)'\n');
        return stream.ToArray();
    }

    public static string ComputeSha256(ReadOnlySpan<byte> bytes)
        => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    private static void ValidatePackage(
        ContentPackageDto package,
        string expectedChannel,
        string expectedArtifact,
        string expectedPathPrefix)
    {
        if (package is null
            || package.Manifest is null
            || package.Manifest.Files is null
            || package.Files is null)
        {
            throw new ContentReleaseValidationException("Both content packages are required.");
        }

        var manifest = package.Manifest;
        EnsureNoAdditionalProperties(package.AdditionalProperties, $"{expectedArtifact} package");
        EnsureNoAdditionalProperties(manifest.AdditionalProperties, $"{expectedArtifact} manifest");
        if (!string.Equals(manifest.Schema, ContentReleaseContracts.PackageManifestSchema, StringComparison.Ordinal)
            || !string.Equals(manifest.Channel, expectedChannel, StringComparison.Ordinal)
            || !string.Equals(manifest.Artifact, expectedArtifact, StringComparison.Ordinal)
            || !string.Equals(manifest.Algorithm, ContentReleaseContracts.Algorithm, StringComparison.Ordinal)
            || !string.Equals(manifest.Serialization, ContentReleaseContracts.Serialization, StringComparison.Ordinal))
        {
            throw new ContentReleaseValidationException(
                $"The {expectedArtifact} manifest does not match the supported package contract.");
        }

        if (!IsSha256(manifest.RootHash)
            || !string.Equals(manifest.ManifestId, $"sha256:{manifest.RootHash}", StringComparison.Ordinal))
        {
            throw new ContentReleaseValidationException(
                $"The {expectedArtifact} manifestId/rootHash pair is invalid.");
        }

        var expectedRootHash = ComputeManifestRootHash(manifest);
        if (!string.Equals(expectedRootHash, manifest.RootHash, StringComparison.Ordinal))
        {
            throw new ContentReleaseValidationException(
                $"The {expectedArtifact} manifest root hash is invalid.");
        }

        if (manifest.FileCount != manifest.Files.Count || manifest.FileCount != package.Files.Count)
        {
            throw new ContentReleaseValidationException(
                $"The {expectedArtifact} manifest fileCount does not match its payload.");
        }

        var entriesByPath = new Dictionary<string, ContentManifestFileDto>(StringComparer.Ordinal);
        var ids = new HashSet<string>(StringComparer.Ordinal);
        foreach (var entry in manifest.Files)
        {
            if (entry is null
                || !IsSafeItemId(entry.Id)
                || !IsSafeArtifactPath(entry.Path, expectedPathPrefix)
                || entry.AdditionalProperties is { Count: > 0 }
                || !ids.Add(entry.Id)
                || !entriesByPath.TryAdd(entry.Path, entry)
                || !IsSha256(entry.Hash)
                || entry.Size < 0)
            {
                throw new ContentReleaseValidationException(
                    $"The {expectedArtifact} manifest contains an invalid or duplicate file entry.");
            }
        }

        var seenPaths = new HashSet<string>(StringComparer.Ordinal);
        foreach (var file in package.Files)
        {
            if (file is null
                || !IsSafeArtifactPath(file.Path, expectedPathPrefix)
                || file.AdditionalProperties is { Count: > 0 }
                || !seenPaths.Add(file.Path)
                || !entriesByPath.TryGetValue(file.Path, out var entry))
            {
                throw new ContentReleaseValidationException(
                    $"The {expectedArtifact} package contains an undeclared or duplicate file.");
            }

            if (file.Content.ValueKind != JsonValueKind.Object
                || !file.Content.TryGetProperty("id", out var idElement)
                || idElement.ValueKind != JsonValueKind.String
                || !string.Equals(idElement.GetString(), entry.Id, StringComparison.Ordinal))
            {
                throw new ContentReleaseValidationException(
                    $"Payload '{file.Path}' does not match manifest item id '{entry.Id}'.");
            }

            if (expectedChannel == "public")
            {
                EnsurePublicPayloadIsSafe(file.Content);
            }

            var canonicalBytes = Canonicalize(file.Content);
            if (canonicalBytes.LongLength != entry.Size
                || !string.Equals(ComputeSha256(canonicalBytes), entry.Hash, StringComparison.Ordinal))
            {
                throw new ContentReleaseValidationException(
                    $"Payload '{file.Path}' does not match its declared SHA-256 and size.");
            }
        }

        if (seenPaths.Count != entriesByPath.Count)
        {
            throw new ContentReleaseValidationException(
                $"The {expectedArtifact} package is missing one or more declared files.");
        }
    }

    private static string ComputeManifestRootHash(ContentPackageManifestDto manifest)
    {
        var body = new Dictionary<string, object?>
        {
            ["schema"] = manifest.Schema,
            ["channel"] = manifest.Channel,
            ["artifact"] = manifest.Artifact,
            ["algorithm"] = manifest.Algorithm,
            ["serialization"] = manifest.Serialization,
            ["fileCount"] = manifest.FileCount,
            ["files"] = manifest.Files
        };
        return ComputeSha256(Canonicalize(JsonSerializer.SerializeToElement(body, JsonOptions)));
    }

    private static bool IsSafeArtifactPath(string path, string expectedPrefix)
        => !string.IsNullOrWhiteSpace(path)
           && path.StartsWith(expectedPrefix, StringComparison.Ordinal)
           && path.EndsWith(".json", StringComparison.Ordinal)
           && !path.Contains('\\')
           && !path.Contains("..", StringComparison.Ordinal)
           && !path.Contains("answerKey", StringComparison.OrdinalIgnoreCase);

    private static void EnsureNoAdditionalProperties(
        IReadOnlyDictionary<string, JsonElement>? additionalProperties,
        string contractPart)
    {
        if (additionalProperties is { Count: > 0 })
        {
            throw new ContentReleaseValidationException(
                $"The {contractPart} contains unsupported properties.");
        }
    }

    private static bool IsSafeItemId(string id)
        => !string.IsNullOrWhiteSpace(id)
           && Encoding.UTF8.GetByteCount(id) <= 200
           && id.All(character =>
               char.IsAsciiLetterOrDigit(character) || character is '-' or '_' or '.');

    private static bool IsSha256(string value)
        => value is { Length: 64 } && value.All(character =>
            character is >= '0' and <= '9' or >= 'a' and <= 'f');

    private static void EnsurePublicPayloadIsSafe(JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    if (property.Name.Equals("answerKey", StringComparison.OrdinalIgnoreCase)
                        || property.Name.Equals("correct", StringComparison.OrdinalIgnoreCase)
                        || property.Name.Equals("rationale", StringComparison.OrdinalIgnoreCase))
                    {
                        throw new ContentReleaseValidationException(
                            $"The public package contains forbidden key '{property.Name}'.");
                    }

                    EnsurePublicPayloadIsSafe(property.Value);
                }
                break;
            case JsonValueKind.Array:
                foreach (var item in element.EnumerateArray())
                {
                    EnsurePublicPayloadIsSafe(item);
                }
                break;
        }
    }

    private static void WriteCanonical(Utf8JsonWriter writer, JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (var property in element.EnumerateObject().OrderBy(
                             property => property.Name,
                             StringComparer.Ordinal))
                {
                    writer.WritePropertyName(property.Name);
                    WriteCanonical(writer, property.Value);
                }
                writer.WriteEndObject();
                break;
            case JsonValueKind.Array:
                writer.WriteStartArray();
                foreach (var item in element.EnumerateArray())
                {
                    WriteCanonical(writer, item);
                }
                writer.WriteEndArray();
                break;
            case JsonValueKind.String:
                writer.WriteStringValue(element.GetString());
                break;
            case JsonValueKind.Number:
                element.WriteTo(writer);
                break;
            case JsonValueKind.True:
                writer.WriteBooleanValue(true);
                break;
            case JsonValueKind.False:
                writer.WriteBooleanValue(false);
                break;
            case JsonValueKind.Null:
                writer.WriteNullValue();
                break;
            default:
                throw new ContentReleaseValidationException(
                    $"Unsupported JSON value kind '{element.ValueKind}'.");
        }
    }
}
