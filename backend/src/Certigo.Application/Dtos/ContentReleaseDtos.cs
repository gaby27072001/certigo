using System.Text.Json;
using System.Text.Json.Serialization;

namespace Certigo.Application.Dtos;

public static class ContentReleaseContracts
{
    public const string ImportContractVersion = "certigo.backend.content-release-import/v1";
    public const string PackageManifestSchema = "certigo.content.package-manifest/v1";
    public const string Algorithm = "sha256";
    public const string Serialization = "json-sorted-keys-compact-utf8-lf";
    public const string ControlScope = "content";
    public const string PublicManifestDocumentId = "manifest";
    public const string PrivateManifestDocumentId = "manifest";

    public static string ReleaseDocumentId(string manifestId) => $"release::{manifestId}";

    public static string StateDocumentId(ContentReleaseEnvironment environment)
        => $"state::{environment.ToString().ToLowerInvariant()}";
}

public enum ContentReleaseEnvironment
{
    Staging,
    Prod
}

public sealed record ContentManifestFileDto(
    string Id,
    string Path,
    string Hash,
    long Size)
{
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? AdditionalProperties { get; init; }
}

public sealed record ContentPackageManifestDto(
    string Schema,
    string Channel,
    string Artifact,
    string Algorithm,
    string Serialization,
    int FileCount,
    IReadOnlyList<ContentManifestFileDto> Files,
    string ManifestId,
    string RootHash)
{
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? AdditionalProperties { get; init; }
}

public sealed record ContentPackageFileDto(
    string Path,
    JsonElement Content)
{
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? AdditionalProperties { get; init; }
}

public sealed record ContentPackageDto(
    ContentPackageManifestDto Manifest,
    IReadOnlyList<ContentPackageFileDto> Files)
{
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? AdditionalProperties { get; init; }
}

public sealed record ImportContentReleaseRequest(
    string ContractVersion,
    ContentPackageDto Public,
    ContentPackageDto Private)
{
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? AdditionalProperties { get; init; }
}

public sealed record RollbackContentReleaseRequest(ContentReleaseEnvironment Environment);

public sealed record ContentReleaseStateDto(
    ContentReleaseEnvironment Environment,
    string ActiveManifestId,
    string? PreviousManifestId);

public sealed record ContentReleaseImportResultDto(
    string ManifestId,
    string PrivateManifestId,
    bool Imported,
    ContentReleaseStateDto Staging);

public sealed record ContentReleaseOperationResultDto(
    ContentReleaseEnvironment Environment,
    string ActiveManifestId,
    string? PreviousManifestId,
    bool Changed);

public sealed record ContentReleaseRecord(
    string Id,
    string Scope,
    string ManifestId,
    string PrivateManifestId,
    DateTimeOffset ImportedAt)
{
    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }
}

public sealed record ContentReleaseStateRecord(
    string Id,
    string Scope,
    ContentReleaseEnvironment Environment,
    string ActiveManifestId,
    string? PreviousManifestId,
    DateTimeOffset UpdatedAt)
{
    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }
}

public sealed record StoredContentManifestRecord(
    string Id,
    string ReleaseId,
    string Type,
    ContentPackageManifestDto Manifest);

public sealed record StoredContentFileRecord(
    string Id,
    string ReleaseId,
    string ManifestId,
    string Type,
    string Path,
    string Hash,
    long Size,
    JsonElement Payload);
