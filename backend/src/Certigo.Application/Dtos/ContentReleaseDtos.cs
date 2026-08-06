using System.Text.Json.Serialization;

namespace Certigo.Application.Dtos;

/// <summary>
/// Versioned import envelope consumed by the backend. The two packages are the
/// independently-produced public/private artifacts from certigo-content.
/// File bytes are base64 encoded so SHA-256 is checked over the exact published
/// bytes, before any repository mutation.
/// </summary>
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ContentReleaseImportRequest(
    string ContractVersion,
    ContentArtifactPackage Public,
    ContentArtifactPackage Private);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ContentArtifactPackage(
    ContentArtifactManifest Manifest,
    IReadOnlyList<ContentArtifactPayload> Files);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ContentArtifactManifest(
    string Schema,
    string Channel,
    string Artifact,
    string Algorithm,
    string Serialization,
    int FileCount,
    IReadOnlyList<ContentArtifactFile> Files,
    string ManifestId,
    string RootHash);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ContentArtifactFile(
    string Id,
    string Path,
    string Hash,
    long Size);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ContentArtifactPayload(string Path, string ContentBase64);

public sealed record ContentReleaseImportResultDto(
    string ManifestId,
    string PublicManifestId,
    bool AlreadyImported,
    int PublicFileCount,
    int PrivateFileCount);

public sealed record ActiveContentManifestDto(
    string ManifestId,
    string Schema,
    string Channel,
    string Artifact,
    string Algorithm,
    string Serialization,
    int FileCount,
    string RootHash,
    IReadOnlyList<ContentArtifactFile> Files);

public sealed record ContentReleaseStateDto(
    string Environment,
    string ActiveManifestId,
    string? PreviousManifestId,
    DateTimeOffset ChangedAt,
    string Operation);

public sealed record ContentReleaseFileDto(string Path, byte[] Content);
