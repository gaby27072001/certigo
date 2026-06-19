namespace Microlingo.Domain.Content;

public sealed record Track(
    string Id,
    string Name,
    string Exam,
    IReadOnlyList<ExamDomain> Domains);

public sealed record ExamDomain(string Id, string Name, double Weight);

public sealed record Unit(
    string Id,
    string TrackId,
    string DomainId,
    int Order,
    string Title,
    IReadOnlyList<string> LessonIds);

public sealed record Lesson(
    string Id,
    string TrackId,
    string UnitId,
    string DomainId,
    int Order,
    string Title,
    int EstMinutes,
    IReadOnlyList<LessonBlock> Blocks,
    IReadOnlyList<string> ItemIds);

public abstract record LessonBlock(string Id, string Kind);

public sealed record ConceptBlock(string Id, string ConceptId, string Title, string Body)
    : LessonBlock(Id, "concept");

public sealed record ExampleBlock(string Id, string ConceptId, string Scenario, string AppliedExample)
    : LessonBlock(Id, "example");

public sealed record CodeBlock(string Id, string Language, string Code, string Caption)
    : LessonBlock(Id, "code");

public sealed record CheckBlock(string Id, string Prompt, IReadOnlyList<string> ItemIds)
    : LessonBlock(Id, "check");

public sealed record HookBlock(string Id, string Text)
    : LessonBlock(Id, "hook");

public sealed record RecapBlock(string Id, IReadOnlyList<string> KeyPoints)
    : LessonBlock(Id, "recap");

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

public sealed record QuizItem(
    string Id,
    string TrackId,
    string ConceptId,
    string DomainId,
    ItemType ItemType,
    string Bloom,
    double Difficulty,
    string Stem,
    IReadOnlyList<Option> Options,
    IReadOnlyList<string> Correct,
    string Explanation);

public sealed record Option(string Id, string Text);

public sealed record Concept(
    string Id,
    string TrackId,
    string DomainId,
    string Title,
    string Summary,
    IReadOnlyList<string> Prerequisites,
    string BloomTarget)
{
    public string Explanation { get; init; } = string.Empty;
    public string AppliedExample { get; init; } = string.Empty;
    public IReadOnlyList<string> Checks { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> ReviewCards { get; init; } = Array.Empty<string>();
}
