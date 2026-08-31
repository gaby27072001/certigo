using Certigo.Domain.Content;

namespace Certigo.Application.Dtos;

// --- Mock exam (adaptive practice exam) ------------------------------------

public sealed record MockExamRequest(
    string TrackId,
    int? Length = null,
    string? PublicManifestId = null);

// Public, answer-free exam item: stem + options come from the lesson's public
// check; the correct answer stays server-side in the answer key.
public sealed record MockExamItemDto(
    string ItemId,
    string LessonId,
    string DomainId,
    ItemType Type,
    string Stem,
    IReadOnlyList<CheckOption> Options);

public sealed record MockExamBlueprintDomainDto(string DomainId, string Name, double Weight, int ItemCount);

public sealed record MockExamDto(
    string ExamId,
    string TrackId,
    string TrackCode,
    string TrackTitle,
    int TimeLimitSeconds,
    int PassingScore,
    IReadOnlyList<MockExamBlueprintDomainDto> Blueprint,
    IReadOnlyList<MockExamItemDto> Items,
    string? PublicManifestId = null);

public sealed record SubmitMockExamRequest(
    string ClientAttemptId,
    string TrackId,
    string ExamId,
    DateTimeOffset StartedAt,
    List<AnswerDto> Answers);

public sealed record ExamDomainScoreDto(string DomainId, string Name, double Weight, int Correct, int Total, int Pct);

public sealed record MockExamResultDto(
    string AttemptId,
    string ExamId,
    int ScaledScore,
    int Pct,
    bool Passed,
    int PassingScore,
    int Correct,
    int Total,
    IReadOnlyList<ExamDomainScoreDto> Domains,
    List<ItemResultDto> Results,
    RewardsDto Rewards,
    List<string> WeakConcepts);
