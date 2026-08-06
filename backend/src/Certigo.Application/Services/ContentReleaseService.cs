using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.RegularExpressions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

public interface IContentReleaseService
{
    Task<ContentReleaseImportResultDto> ImportAsync(
        ContentReleaseImportRequest request,
        CancellationToken cancellationToken = default);

    Task<ContentReleaseStateDto> PromoteAsync(
        string manifestId,
        CancellationToken cancellationToken = default);

    Task<ContentReleaseStateDto> RollbackAsync(
        string manifestId,
        CancellationToken cancellationToken = default);

    Task<ActiveContentManifestDto?> GetActiveManifestAsync(
        CancellationToken cancellationToken = default);

    Task<ContentReleaseFileDto?> GetActivePublicFileAsync(
        string path,
        CancellationToken cancellationToken = default);
}

public sealed class ContentReleaseOptions
{
    public const string ContractVersion = "certigo-content-release/v1";
    public const string PackageManifestSchema = "certigo.content.package-manifest/v1";
    public const string HashAlgorithm = "sha256";
    public const string Serialization = "json-sorted-keys-compact-utf8-lf";

    public ContentReleaseOptions(string environment)
    {
        var normalized = string.IsNullOrWhiteSpace(environment)
            ? "development"
            : environment.Trim().ToLowerInvariant();
        Environment = normalized switch
        {
            "development" => "dev",
            "production" => "prod",
            "dev" or "staging" or "prod" => normalized,
            _ => throw new InvalidOperationException(
                "CONTENT_RELEASE_ENVIRONMENT must be dev, staging, or prod.")
        };
    }

    public string Environment { get; }
}

public sealed class ContentReleaseService(
    IContentReleaseRepository repository,
    IPublicContentReleaseRepository publicRepository,
    IContentReleaseTelemetry telemetry,
    IClock clock,
    ContentReleaseOptions options) : IContentReleaseService
{
    private const int MaxFilesPerChannel = 500;
    // Cosmos has a 2 MB item limit; base64 expands by ~33%, so leave ample room
    // for document metadata and serializer overhead.
    private const int MaxFileBytes = 1_000_000;
    private const long MaxChannelBytes = 25_000_000;
    private const int MaxReceiptManifestBytes = 512_000;
    private const int MaxFileIdLength = 256;
    private static readonly Regex Sha256Pattern = new(
        "^(?:sha256:)?[a-fA-F0-9]{64}$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);
    private static readonly Regex CanonicalFileHashPattern = new(
        "^[a-f0-9]{64}$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);
    private static readonly JsonSerializerOptions CanonicalJsonOptions = new(JsonSerializerDefaults.Web)
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };

    public async Task<ContentReleaseImportResultDto> ImportAsync(
        ContentReleaseImportRequest request,
        CancellationToken cancellationToken = default)
    {
        VerifiedContentRelease release;
        try
        {
            release = Verify(request);
        }
        catch (ContentReleaseValidationException ex)
        {
            telemetry.TrackRejected(Reason(ex.Message));
            throw;
        }

        bool alreadyImported;
        try
        {
            alreadyImported = await repository.ImportAsync(release, cancellationToken);
        }
        catch (ContentReleaseValidationException ex)
        {
            telemetry.TrackRejected(Reason(ex.Message));
            throw;
        }
        telemetry.TrackImported(
            release.ManifestId,
            alreadyImported,
            release.PublicManifest.Files.Count,
            release.PrivateManifest.Files.Count);
        return new ContentReleaseImportResultDto(
            release.ManifestId,
            release.PublicManifestId,
            alreadyImported,
            release.PublicManifest.Files.Count,
            release.PrivateManifest.Files.Count);
    }

    public async Task<ContentReleaseStateDto> PromoteAsync(
        string manifestId,
        CancellationToken cancellationToken = default)
    {
        var normalized = NormalizeManifestId(manifestId);
        ContentReleasePromotionResult promotion;
        try
        {
            promotion = await repository.PromoteAsync(
                options.Environment,
                normalized,
                ContentReleaseOperation.Promote,
                clock.UtcNow,
                cancellationToken);
        }
        catch (ContentReleaseValidationException ex)
        {
            telemetry.TrackRejected(Reason(ex.Message));
            throw;
        }
        catch (ContentReleaseNotFoundException)
        {
            telemetry.TrackRejected("manifest_not_imported");
            throw;
        }
        if (promotion.Changed)
        {
            telemetry.TrackPromoted(options.Environment, normalized);
        }
        return ToDto(promotion.State);
    }

    public async Task<ContentReleaseStateDto> RollbackAsync(
        string manifestId,
        CancellationToken cancellationToken = default)
    {
        var normalized = NormalizeManifestId(manifestId);
        ContentReleasePromotionResult promotion;
        try
        {
            promotion = await repository.PromoteAsync(
                options.Environment,
                normalized,
                ContentReleaseOperation.Rollback,
                clock.UtcNow,
                cancellationToken);
        }
        catch (ContentReleaseValidationException ex)
        {
            telemetry.TrackRejected(Reason(ex.Message));
            throw;
        }
        catch (ContentReleaseNotFoundException)
        {
            telemetry.TrackRejected("rollback_manifest_not_imported");
            throw;
        }
        if (promotion.Changed)
        {
            telemetry.TrackRolledBack(options.Environment, normalized);
        }
        return ToDto(promotion.State);
    }

    public async Task<ActiveContentManifestDto?> GetActiveManifestAsync(
        CancellationToken cancellationToken = default)
    {
        var state = await repository.GetStateAsync(options.Environment, cancellationToken);
        if (state is null)
        {
            return null;
        }

        var receipt = await repository.GetReceiptAsync(state.ActiveManifestId, cancellationToken);
        if (receipt is null)
        {
            throw new InvalidOperationException(
                $"Active content release '{state.ActiveManifestId}' has no immutable receipt.");
        }

        var manifest = receipt.PublicManifest;
        return new ActiveContentManifestDto(
            manifest.ManifestId,
            manifest.Schema,
            manifest.Channel,
            manifest.Artifact,
            manifest.Algorithm,
            manifest.Serialization,
            manifest.FileCount,
            manifest.RootHash,
            manifest.Files);
    }

    public async Task<ContentReleaseFileDto?> GetActivePublicFileAsync(
        string path,
        CancellationToken cancellationToken = default)
    {
        var normalizedPath = NormalizePath(path);
        var file = await publicRepository.GetActivePublicFileAsync(
            options.Environment,
            normalizedPath,
            cancellationToken);
        return file is null ? null : new ContentReleaseFileDto(file.Path, file.Content);
    }

    private VerifiedContentRelease Verify(ContentReleaseImportRequest request)
    {
        if (request is null)
        {
            throw Invalid("request_required");
        }

        if (!string.Equals(
                request.ContractVersion,
                ContentReleaseOptions.ContractVersion,
                StringComparison.Ordinal))
        {
            throw Invalid("unsupported_contract_version");
        }

        var publicFiles = VerifyPackage(
            request.Public,
            validationName: "public",
            expectedChannel: "public",
            expectedArtifact: "public",
            scanForPrivateData: true);
        var privateFiles = VerifyPackage(
            request.Private,
            validationName: "private",
            expectedChannel: "answerKey",
            expectedArtifact: "private",
            scanForPrivateData: false);
        var publicManifestId = NormalizeManifestId(request.Public.Manifest.ManifestId);
        var privateManifestId = NormalizeManifestId(request.Private.Manifest.ManifestId);
        if (string.Equals(publicManifestId, privateManifestId, StringComparison.Ordinal))
        {
            throw Invalid("channel_manifest_ids_must_differ");
        }
        var publicManifest = request.Public.Manifest;
        var privateManifest = request.Private.Manifest;
        var receiptManifestBytes =
            JsonSerializer.SerializeToUtf8Bytes(publicManifest).Length
            + JsonSerializer.SerializeToUtf8Bytes(privateManifest).Length;
        if (receiptManifestBytes > MaxReceiptManifestBytes)
        {
            throw Invalid("receipt_manifest_too_large");
        }
        var fingerprint = Fingerprint(publicManifest, privateManifest);
        var releaseManifestId = ReleaseManifestId(publicManifestId, privateManifestId);
        return new VerifiedContentRelease(
            releaseManifestId,
            publicManifestId,
            fingerprint,
            publicManifest,
            privateManifest,
            publicFiles.Concat(privateFiles).ToArray(),
            clock.UtcNow);
    }

    private static IReadOnlyList<VerifiedContentReleaseFile> VerifyPackage(
        ContentArtifactPackage package,
        string validationName,
        string expectedChannel,
        string expectedArtifact,
        bool scanForPrivateData)
    {
        if (package?.Manifest is null || package.Files is null)
        {
            throw Invalid($"{validationName}_package_required");
        }

        var manifest = package.Manifest;
        if (!string.Equals(
                manifest.Schema,
                ContentReleaseOptions.PackageManifestSchema,
                StringComparison.Ordinal))
        {
            throw Invalid($"{validationName}_manifest_schema_mismatch");
        }
        if (!string.Equals(manifest.Channel, expectedChannel, StringComparison.Ordinal))
        {
            throw Invalid($"{validationName}_channel_mismatch");
        }
        if (!string.Equals(
                manifest.Artifact,
                expectedArtifact,
                StringComparison.Ordinal))
        {
            throw Invalid($"{validationName}_artifact_mismatch");
        }
        if (!string.Equals(
                manifest.Algorithm,
                ContentReleaseOptions.HashAlgorithm,
                StringComparison.Ordinal))
        {
            throw Invalid($"{validationName}_algorithm_mismatch");
        }
        if (!string.Equals(
                manifest.Serialization,
                ContentReleaseOptions.Serialization,
                StringComparison.Ordinal))
        {
            throw Invalid($"{validationName}_serialization_mismatch");
        }

        if (manifest.Files is null || manifest.Files.Count == 0)
        {
            throw Invalid($"{validationName}_manifest_empty");
        }

        if (manifest.Files.Count > MaxFilesPerChannel)
        {
            throw Invalid($"{validationName}_too_many_files");
        }
        if (manifest.FileCount != manifest.Files.Count)
        {
            throw Invalid($"{validationName}_file_count_mismatch");
        }
        VerifyRootHash(manifest, validationName);

        var descriptors = new Dictionary<string, ContentArtifactFile>(StringComparer.Ordinal);
        var ids = new HashSet<string>(StringComparer.Ordinal);
        var expectedPath = validationName == "public"
            ? new Regex(
                @"^questions/[^/]+\.json$",
                RegexOptions.CultureInvariant | RegexOptions.Compiled)
            : new Regex(
                @"^solutions/[^/]+\.json$",
                RegexOptions.CultureInvariant | RegexOptions.Compiled);
        foreach (var descriptor in manifest.Files)
        {
            if (descriptor is null)
            {
                throw Invalid($"{validationName}_invalid_manifest_file");
            }
            var path = NormalizePath(descriptor.Path);
            if (!string.Equals(path, descriptor.Path, StringComparison.Ordinal))
            {
                throw Invalid($"{validationName}_unsafe_file_path");
            }
            if (!expectedPath.IsMatch(path))
            {
                throw Invalid($"{validationName}_file_path_mismatch");
            }
            if (string.IsNullOrWhiteSpace(descriptor.Id)
                || descriptor.Id.Length > MaxFileIdLength
                || !ids.Add(descriptor.Id))
            {
                throw Invalid($"{validationName}_invalid_or_duplicate_file_id");
            }
            if (string.IsNullOrWhiteSpace(descriptor.Hash)
                || !CanonicalFileHashPattern.IsMatch(descriptor.Hash))
            {
                throw Invalid($"{validationName}_non_canonical_file_hash");
            }
            var hash = descriptor.Hash;
            if (descriptor.Size <= 0 || descriptor.Size > MaxFileBytes)
            {
                throw Invalid($"{validationName}_invalid_file_size");
            }

            if (!descriptors.TryAdd(path, descriptor with { Path = path, Hash = hash }))
            {
                throw Invalid($"{validationName}_duplicate_manifest_path");
            }
        }
        if (descriptors.Values.Sum(x => x.Size) > MaxChannelBytes)
        {
            throw Invalid($"{validationName}_package_too_large");
        }

        var payloads = new Dictionary<string, ContentArtifactPayload>(StringComparer.Ordinal);
        foreach (var payload in package.Files)
        {
            if (payload is null)
            {
                throw Invalid($"{validationName}_invalid_payload");
            }
            var path = NormalizePath(payload.Path);
            if (!payloads.TryAdd(path, payload))
            {
                throw Invalid($"{validationName}_duplicate_payload_path");
            }
        }

        if (descriptors.Count != payloads.Count
            || descriptors.Keys.Any(path => !payloads.ContainsKey(path)))
        {
            throw Invalid($"{validationName}_file_set_mismatch");
        }

        var verified = new List<VerifiedContentReleaseFile>(descriptors.Count);
        foreach (var (path, descriptor) in descriptors.OrderBy(x => x.Key, StringComparer.Ordinal))
        {
            byte[] content;
            var contentBase64 = payloads[path].ContentBase64;
            var maxEncodedLength = ((MaxFileBytes + 2) / 3) * 4;
            if (string.IsNullOrWhiteSpace(contentBase64)
                || contentBase64.Length > maxEncodedLength)
            {
                throw Invalid($"{validationName}_invalid_base64");
            }
            try
            {
                content = Convert.FromBase64String(contentBase64);
            }
            catch (FormatException)
            {
                throw Invalid($"{validationName}_invalid_base64");
            }

            if (content.LongLength != descriptor.Size)
            {
                throw Invalid($"{validationName}_size_mismatch");
            }

            var actualHash = Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant();
            if (!CryptographicOperations.FixedTimeEquals(
                    Encoding.ASCII.GetBytes(actualHash),
                    Encoding.ASCII.GetBytes(descriptor.Hash)))
            {
                throw Invalid($"{validationName}_hash_mismatch");
            }

            if (scanForPrivateData)
            {
                EnsurePublic(path, content);
            }

            verified.Add(new VerifiedContentReleaseFile(
                expectedChannel,
                descriptor.Id,
                path,
                descriptor.Hash,
                descriptor.Size,
                content));
        }

        return verified;
    }

    private static void EnsurePublic(string path, byte[] content)
    {
        if (path.Split('/').Any(segment =>
                segment.Contains("answerkey", StringComparison.OrdinalIgnoreCase)))
        {
            throw Invalid("public_answer_key_path");
        }
        try
        {
            using var document = JsonDocument.Parse(content);
            EnsurePublicJson(document.RootElement);
        }
        catch (JsonException)
        {
            throw Invalid("public_invalid_json");
        }
    }

    private static void EnsurePublicJson(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in element.EnumerateObject())
            {
                if (property.Name.Equals("answerKey", StringComparison.OrdinalIgnoreCase)
                    || property.Name.Equals("correct", StringComparison.OrdinalIgnoreCase)
                    || property.Name.Equals("rationale", StringComparison.OrdinalIgnoreCase))
                {
                    throw Invalid("public_private_key");
                }

                EnsurePublicJson(property.Value);
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in element.EnumerateArray())
            {
                EnsurePublicJson(item);
            }
        }
    }

    private static string Fingerprint(
        ContentArtifactManifest publicManifest,
        ContentArtifactManifest privateManifest)
        => Convert.ToHexString(SHA256.HashData(Canonicalize(
                new { Public = publicManifest, Private = privateManifest })))
            .ToLowerInvariant();

    private static string ReleaseManifestId(
        string publicManifestId,
        string privateManifestId)
    {
        var identity = Encoding.UTF8.GetBytes(
            $"{publicManifestId}\n{privateManifestId}\n");
        return $"sha256:{Convert.ToHexString(SHA256.HashData(identity)).ToLowerInvariant()}";
    }

    private static void VerifyRootHash(
        ContentArtifactManifest manifest,
        string expectedChannel)
    {
        var rootHash = NormalizeSha256(manifest.RootHash);
        var manifestId = NormalizeManifestId(manifest.ManifestId);
        if (!string.Equals(manifest.RootHash, rootHash, StringComparison.Ordinal)
            || !string.Equals(manifest.ManifestId, manifestId, StringComparison.Ordinal))
        {
            throw Invalid($"{expectedChannel}_non_canonical_hash_format");
        }
        if (!string.Equals(manifestId, $"sha256:{rootHash}", StringComparison.Ordinal))
        {
            throw Invalid($"{expectedChannel}_manifest_id_root_mismatch");
        }

        var canonicalBody = Canonicalize(new
        {
            manifest.Schema,
            manifest.Channel,
            manifest.Artifact,
            manifest.Algorithm,
            manifest.Serialization,
            manifest.FileCount,
            manifest.Files
        });
        var actualRootHash = Convert.ToHexString(SHA256.HashData(canonicalBody))
            .ToLowerInvariant();
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(actualRootHash),
                Encoding.ASCII.GetBytes(rootHash)))
        {
            throw Invalid($"{expectedChannel}_root_hash_mismatch");
        }
    }

    private static byte[] Canonicalize<T>(T value)
    {
        var element = JsonSerializer.SerializeToElement(value, CanonicalJsonOptions);
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            Indented = false
        }))
        {
            WriteCanonical(writer, element);
            writer.Flush();
        }
        return stream.ToArray();
    }

    private static void WriteCanonical(Utf8JsonWriter writer, JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (var property in element.EnumerateObject()
                             .OrderBy(x => x.Name, StringComparer.Ordinal))
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
            default:
                element.WriteTo(writer);
                break;
        }
    }

    private static string NormalizeManifestId(string manifestId)
    {
        if (string.IsNullOrWhiteSpace(manifestId)
            || !manifestId.StartsWith("sha256:", StringComparison.Ordinal)
            || !Sha256Pattern.IsMatch(manifestId))
        {
            throw Invalid("invalid_manifest_id");
        }

        return $"sha256:{manifestId[7..].ToLowerInvariant()}";
    }

    private static string NormalizeSha256(string hash)
    {
        if (string.IsNullOrWhiteSpace(hash) || !Sha256Pattern.IsMatch(hash))
        {
            throw Invalid("invalid_sha256");
        }

        return hash.StartsWith("sha256:", StringComparison.OrdinalIgnoreCase)
            ? hash[7..].ToLowerInvariant()
            : hash.ToLowerInvariant();
    }

    private static string NormalizePath(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            throw Invalid("invalid_path");
        }

        var normalized = path.Replace('\\', '/').TrimStart('/');
        if (normalized.Length > 512
            || normalized.EndsWith("/", StringComparison.Ordinal)
            || normalized.Split('/').Any(segment =>
                segment.Length == 0 || segment is "." or ".."))
        {
            throw Invalid("invalid_path");
        }

        return normalized;
    }

    private static ContentReleaseValidationException Invalid(string reason)
        => new($"Content release rejected: {reason}.");

    private static string Reason(string message)
    {
        const string prefix = "Content release rejected: ";
        return message.StartsWith(prefix, StringComparison.Ordinal)
            ? message[prefix.Length..].TrimEnd('.')
            : "validation_failed";
    }

    private static ContentReleaseStateDto ToDto(ContentReleaseState state)
        => new(
            state.Environment,
            state.ActiveManifestId,
            state.PreviousManifestId,
            state.ChangedAt,
            state.Operation.ToString().ToLowerInvariant());
}
