namespace Certigo.Application.Dtos;

// The "next best action" coach. The client renders Items as a ranked list of cards
// on the home/path screen; the top item is what we believe the learner should do
// right now to raise readiness while honouring forgetting risk and active struggles.
public sealed record NextBestDto(
    string TrackId,
    DateTimeOffset GeneratedAt,
    IReadOnlyList<RecommendationItemDto> Items);

// One coach card. Kind is the wire-friendly action ("practice" | "review" | "resume"
// | "start"); Reason is a short, localized (French) sentence; Priority/MasteryPct/
// ForgettingRiskPct are 0-100 integers so the UI can show urgency without re-deriving.
public sealed record RecommendationItemDto(
    string Kind,
    string? LessonId,
    string? UnitId,
    string? ConceptId,
    string Title,
    string DomainId,
    string DomainName,
    string Reason,
    int EstMinutes,
    int Priority,
    int MasteryPct,
    int ForgettingRiskPct);
