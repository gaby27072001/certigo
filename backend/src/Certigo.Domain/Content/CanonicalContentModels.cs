namespace Certigo.Domain.Content;

public sealed record CanonicalContentLifecycle(
    string Status,
    DateOnly? RetiredOn = null,
    string? ReplacedBy = null);

public sealed record CanonicalCertification(
    string Id,
    string Slug,
    string? OfficialCode,
    string Title,
    string Level,
    string Status,
    string BlueprintVersion,
    IReadOnlyList<CanonicalCertificationObjective> Objectives);

public sealed record CanonicalCertificationObjective(
    string Id,
    string Title,
    decimal WeightPercent);

public sealed record CanonicalTrackResource(
    string Id,
    string? LegacyId,
    string CertificationId,
    string BlueprintVersion,
    string Mode,
    string Summary,
    IReadOnlyList<string> DomainIds,
    IReadOnlyList<string> UnitIds,
    CanonicalContentLifecycle Lifecycle);

public sealed record CanonicalDomainResource(
    string Id,
    string? LegacyId,
    string CertificationId,
    string BlueprintVersion,
    string ObjectiveId,
    CanonicalContentLifecycle Lifecycle);

public sealed record CanonicalUnitResource(
    string Id,
    string? LegacyId,
    string CertificationId,
    string BlueprintVersion,
    string DomainId,
    string Title,
    IReadOnlyList<string> LessonIds,
    CanonicalContentLifecycle Lifecycle);

public sealed record CanonicalLessonResource(
    string Id,
    string? LegacyId,
    string CertificationId,
    string BlueprintVersion,
    string UnitId,
    string Title,
    int EstimatedMinutes,
    IReadOnlyList<CanonicalLessonBlock> Blocks,
    CanonicalContentLifecycle Lifecycle);

public sealed record CanonicalLessonBlock(
    string Id,
    string Type,
    string ConceptId,
    string? Title = null,
    string? Body = null,
    string? Code = null,
    string? Language = null,
    string? QuestionId = null);

public sealed record CanonicalConceptResource(
    string Id,
    string? LegacyId,
    string CertificationId,
    string BlueprintVersion,
    string DomainId,
    string Title,
    CanonicalContentLifecycle Lifecycle);

public sealed record CanonicalQuestion(
    string Id,
    string? LegacyId,
    string CertificationId,
    string BlueprintVersion,
    string ObjectiveId,
    string DomainId,
    string ConceptId,
    ItemType ItemType,
    int Difficulty,
    string Prompt,
    IReadOnlyList<CheckOption> Options);

public sealed record CanonicalSolution(
    string Id,
    IReadOnlyList<string> CorrectOptionIds,
    string Rationale);

public sealed record CanonicalContentGraph(
    IReadOnlyDictionary<string, CanonicalCertification> Certifications,
    IReadOnlyDictionary<string, CanonicalTrackResource> Tracks,
    IReadOnlyDictionary<string, CanonicalDomainResource> Domains,
    IReadOnlyDictionary<string, CanonicalUnitResource> Units,
    IReadOnlyDictionary<string, CanonicalLessonResource> Lessons,
    IReadOnlyDictionary<string, CanonicalConceptResource> Concepts,
    IReadOnlyDictionary<string, CanonicalQuestion> Questions,
    IReadOnlyDictionary<string, CanonicalSolution> Solutions);

public sealed record ProjectedTrackDocument(
    string CanonicalId,
    string? LegacyId,
    string RuntimeId,
    string LifecycleStatus,
    Track Track);

public sealed record ProjectedLessonDocument(
    string CanonicalId,
    string? LegacyId,
    string RuntimeId,
    string LifecycleStatus,
    Lesson Lesson);

public sealed record ProjectedAnswerKeyDocument(
    string CanonicalLessonId,
    string? LegacyLessonId,
    string RuntimeLessonId,
    string LifecycleStatus,
    LessonAnswerKey AnswerKey);

public sealed record RuntimeContentProjection(
    IReadOnlyList<ProjectedTrackDocument> Tracks,
    IReadOnlyList<ProjectedLessonDocument> Lessons,
    IReadOnlyList<ProjectedAnswerKeyDocument> AnswerKeys);

public sealed class ContentProjectionException(string message) : Exception(message);
