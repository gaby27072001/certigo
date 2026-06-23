namespace Microlingo.Domain.Content;

/// A certification track: weighted exam domains plus the ordered units that make
/// up the skill-path. Deserialized from the Cosmos `content` document
/// `track::{trackId}` (compiled from content/<track>/track.yaml).
public sealed record Track(
    string Id,
    string Code,
    string Title,
    string Summary,
    IReadOnlyList<ExamDomain> Domains,
    IReadOnlyList<TrackUnit> Units,
    string? Level = null);

public sealed record ExamDomain(string Id, string Name, double Weight);

public sealed record TrackUnit(
    string Id,
    string DomainId,
    string Title,
    IReadOnlyList<string> Lessons);

/// The kinds of interaction a check/quiz item supports. Serialized as a
/// camelCase string ("mcq", "matchPairs"…) so the wire contract matches the
/// Flutter `ItemType` enum exactly.
public enum ItemType
{
    Mcq,
    Multi,
    Scenario,
    Cloze,
    Ordering,
    MatchPairs,
    SpotTheIssue,
    Applied
}

public sealed record CheckOption(string Id, string Label);

/// The *public* shape of a check — what ships to the client inside a lesson
/// block. It deliberately omits the correct answer and explanation; grading is
/// authoritative server-side via <see cref="LessonAnswerKey"/>.
public sealed record LessonCheck(
    string Id,
    string ConceptId,
    ItemType Type,
    string Stem,
    IReadOnlyList<CheckOption> Options);

/// One block of a lesson. Flattened (not polymorphic) so it round-trips cleanly
/// through System.Text.Json and matches the Flutter `LessonBlock` 1:1: consumers
/// switch on <see cref="Type"/> (hook|concept|example|code|check|recap).
public sealed record LessonBlock(
    string Type,
    string ConceptId,
    string? Title = null,
    string? Body = null,
    string? Code = null,
    string? Language = null,
    LessonCheck? Check = null);

/// A public lesson: an ordered list of typed blocks driving the Learn Loop.
/// Deserialized from the Cosmos document whose id == lessonId.
public sealed record Lesson(
    string Id,
    string TrackId,
    string UnitId,
    string DomainId,
    string Title,
    int EstMinutes,
    IReadOnlyList<LessonBlock> Blocks);

/// Server-only answer key for a lesson's checks. Stored as the Cosmos document
/// `answerkey::{lessonId}` and never sent to clients. Carries everything the
/// grading engine needs (correct ids, explanation, item type & difficulty for
/// XP) so the public lesson can stay answer-free.
public sealed record LessonAnswerKey(
    string LessonId,
    string TrackId,
    string DomainId,
    IReadOnlyList<AnswerKeyItem> Items);

public sealed record AnswerKeyItem(
    string ItemId,
    string ConceptId,
    ItemType Type,
    int Difficulty,
    IReadOnlyList<string> Correct,
    string Explanation);
