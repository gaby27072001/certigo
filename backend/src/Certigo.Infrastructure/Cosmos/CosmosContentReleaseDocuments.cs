using System.Text.Json.Serialization;

namespace Certigo.Infrastructure.Cosmos;

internal sealed record CosmosVersionedContentDocument<T>(
    string Id,
    string ReleaseId,
    string DocumentType,
    string RuntimeId,
    string? TrackId,
    string CanonicalId,
    string? LegacyId,
    string? LifecycleStatus,
    string PayloadHash,
    T Payload);

internal sealed record ContentReleaseAuditRecord(
    string Id,
    string Scope,
    string Type,
    string ReleaseId,
    string? PreviousReleaseId,
    string ActorId,
    DateTimeOffset OccurredAt);

internal sealed record ContentReleaseActivationRecord(
    string Id,
    string Scope,
    string ReleaseId,
    DateTimeOffset FirstActivatedAt,
    string FirstActivatedBy);

internal sealed record PublicManifestReleaseBinding(
    string Id,
    string Scope,
    string PublicManifestId,
    string PrivateManifestId,
    string ReleaseId);

internal sealed record ContentControlReceipt(
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
    string BlobVersionDigest)
{
    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }
}
