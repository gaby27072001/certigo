namespace Certigo.Application.Abstractions;

public sealed record PilotContentPackage(
    string PilotId,
    string ContentDigest,
    byte[] Json,
    IReadOnlySet<string> LessonIds);

public interface IPilotContentCatalog
{
    Task<PilotContentPackage?> GetAsync(
        string pilotId,
        CancellationToken cancellationToken = default);
}

public sealed record PilotLessonHistoryRecord(
    string Id,
    string UserId,
    string PilotId,
    string ContentDigest,
    string LessonId,
    DateTimeOffset LastAccessedAt,
    DateTimeOffset? MarkedReadAt);

public interface IPilotHistoryRepository
{
    Task<IReadOnlyList<PilotLessonHistoryRecord>> ListAsync(
        string userId,
        string pilotId,
        string contentDigest,
        CancellationToken cancellationToken = default);

    Task<PilotLessonHistoryRecord> RecordAsync(
        PilotLessonHistoryRecord activity,
        bool markRead,
        CancellationToken cancellationToken = default);
}
