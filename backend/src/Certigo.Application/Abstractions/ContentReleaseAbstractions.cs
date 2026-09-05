using System.Text.Json;
using System.Text.Json.Serialization;
using Certigo.Application.Services;
using Certigo.Domain.Content;

namespace Certigo.Application.Abstractions;

public static class ContentReleaseContracts
{
    public const string ReleaseV1 = "certigo.content.release/v1";
    public const string PackageManifestV1 = "certigo.content.package-manifest/v1";
    public const string PackageManifestV2 = "certigo.content.package-manifest/v2";
    public const string PackageManifestV3 = "certigo.content.package-manifest/v3";
    public const string RuntimeScope = "runtime-content";
    public const string LegacySource = "legacy";
    public const string VersionedSource = "versioned";

    public static void RequireDigestId(string value, string parameterName)
    {
        const string prefix = "sha256:";
        if (value.Length == prefix.Length + 64
            && value.StartsWith(prefix, StringComparison.Ordinal)
            && value[prefix.Length..].All(character =>
                character is >= '0' and <= '9' or >= 'a' and <= 'f'))
        {
            return;
        }

        throw new ContentReleaseValidationException(
            $"{parameterName} must be a lowercase sha256 content identity.");
    }
}

public enum ContentArtifact
{
    Public,
    Private,
}

public sealed record ContentSnapshot(
    string Source,
    string? ReleaseId,
    string? PublicManifestId)
{
    public static ContentSnapshot Legacy { get; } =
        new(ContentReleaseContracts.LegacySource, null, null);

    public bool IsLegacy =>
        string.Equals(Source, ContentReleaseContracts.LegacySource, StringComparison.Ordinal);
}

public sealed record ContentBlobObject(
    string Path,
    string VersionId,
    string ETag,
    bool IsImmutable,
    ReadOnlyMemory<byte> Content);

public sealed record ContentReleaseDescriptor(
    string Schema,
    string Algorithm,
    string Canonicalization,
    string PublicManifestId,
    string PrivateManifestId,
    string ReleaseId);

public sealed record ContentPackageFile(
    string Id,
    string Path,
    string? ResourceType,
    string Hash,
    long Size,
    string? Provider = null,
    string? Certification = null,
    string? BlueprintVersion = null,
    string? Objective = null);

public sealed record ContentPackageManifest(
    string Schema,
    string Channel,
    string Artifact,
    string Algorithm,
    string Serialization,
    int FileCount,
    IReadOnlyList<ContentPackageFile> Files,
    string ManifestId,
    string RootHash,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    string? ReleaseId = null);

public sealed record ContentBlobVersion(
    string Path,
    string VersionId,
    string ETag);

public sealed record VerifiedContentRelease(
    ContentReleaseDescriptor Descriptor,
    ContentPackageManifest PublicManifest,
    ContentPackageManifest PrivateManifest,
    CertificationCatalogDocument Catalog,
    CanonicalContentGraph Graph,
    IReadOnlyDictionary<string, JsonElement> PublicResources,
    IReadOnlyDictionary<string, JsonElement> PrivateResources,
    IReadOnlyList<ContentBlobVersion> BlobVersions);

public sealed record ProjectedContentRelease(
    VerifiedContentRelease Verified,
    RuntimeContentProjection Projection);

public sealed record ContentReleaseReceipt(
    string Id,
    string Scope,
    string ReleaseId,
    string PublicManifestId,
    string PrivateManifestId,
    int TrackCount,
    int LessonCount,
    int AnswerKeyCount,
    DateTimeOffset ImportedAt,
    string ImportedBy,
    int BlobVersionCount,
    string BlobVersionDigest);

public sealed record ActiveContentPointer(
    string Id,
    string Scope,
    string ActiveReleaseId,
    string ActivePublicManifestId,
    string? PreviousReleaseId,
    string? PreviousPublicManifestId,
    DateTimeOffset UpdatedAt,
    string UpdatedBy)
{
    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }
}

public sealed record ContentImportResult(
    ContentReleaseReceipt Receipt,
    bool AlreadyImported);

public sealed record ActivePublicManifestResult(
    ContentPackageManifest Manifest,
    string ReleaseId,
    string ETag);

public sealed record PublicContentFileResult(
    string ReleaseId,
    string PublicManifestId,
    string Path,
    string Hash,
    string ContentType,
    ReadOnlyMemory<byte> Content);

public sealed record PublicContentDeliveryOptions(bool Enabled);

public sealed record ContentReleaseLimits(
    int MaxFiles,
    int MaxFileBytes,
    long MaxReleaseBytes,
    int MaxCosmosItemBytes)
{
    public static ContentReleaseLimits Default { get; } =
        new(
            MaxFiles: 10_000,
            MaxFileBytes: 2 * 1024 * 1024,
            MaxReleaseBytes: 128L * 1024 * 1024,
            MaxCosmosItemBytes: 1_900_000);
}

public interface IContentReleaseSource
{
    Task<ContentBlobObject> ReadReleaseAsync(
        string releaseId,
        CancellationToken cancellationToken = default);

    Task<ContentBlobObject> ReadManifestAsync(
        ContentArtifact artifact,
        string manifestId,
        CancellationToken cancellationToken = default);

    Task<ContentBlobObject> ReadFileAsync(
        ContentArtifact artifact,
        string manifestId,
        string path,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<string>> ListFilesAsync(
        ContentArtifact artifact,
        string manifestId,
        CancellationToken cancellationToken = default);
}

public interface IContentSchemaValidator
{
    void Validate(string schemaFileName, JsonElement value);
}

public interface IContentReleaseStore
{
    Task<ContentReleaseReceipt?> GetReceiptAsync(
        string releaseId,
        CancellationToken cancellationToken = default);

    Task<ContentReleaseReceipt> StageAsync(
        ProjectedContentRelease release,
        string actorId,
        DateTimeOffset importedAt,
        CancellationToken cancellationToken = default);

    Task<ActiveContentPointer?> GetActivePointerAsync(
        CancellationToken cancellationToken = default);

    Task<ContentSnapshot?> ResolveSnapshotAsync(
        string publicManifestId,
        CancellationToken cancellationToken = default);

    Task<ActiveContentPointer> PromoteAsync(
        string releaseId,
        string expectedETag,
        string actorId,
        DateTimeOffset promotedAt,
        CancellationToken cancellationToken = default);

    Task<ActiveContentPointer> RollbackAsync(
        string expectedETag,
        string actorId,
        DateTimeOffset rolledBackAt,
        CancellationToken cancellationToken = default);

    Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
        CancellationToken cancellationToken = default);
}

public interface IContentReleaseTelemetry
{
    void TrackImport(string releaseId, bool alreadyImported, TimeSpan duration);
    void TrackRejection(string releaseId, string reason, TimeSpan duration);
    void TrackPromotion(string releaseId, string? previousReleaseId);
    void TrackRollback(string releaseId, string rolledBackFromReleaseId);
}

public sealed class NullContentReleaseTelemetry : IContentReleaseTelemetry
{
    public void TrackImport(string releaseId, bool alreadyImported, TimeSpan duration)
    {
    }

    public void TrackRejection(string releaseId, string reason, TimeSpan duration)
    {
    }

    public void TrackPromotion(string releaseId, string? previousReleaseId)
    {
    }

    public void TrackRollback(string releaseId, string rolledBackFromReleaseId)
    {
    }
}

public sealed class ContentReleaseValidationException(string message, Exception? innerException = null)
    : Exception(message, innerException);

public sealed class ContentReleaseNotFoundException(string message) : Exception(message);

public sealed class ContentReleaseStateException(string message) : Exception(message);

public sealed class ContentReleasePreconditionException(string message) : Exception(message);

public sealed class ContentReleasePreconditionRequiredException(string message) : Exception(message);

public sealed class ContentAccessForbiddenException(string message) : Exception(message);

public sealed class ContentUnavailableException(string message) : Exception(message);
