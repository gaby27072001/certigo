namespace Certigo.Application.Dtos;

// "Explain my answer" — the premium AI-tutor entry point. The learner posts the
// item they just answered (and what they chose); the service grounds, personalises
// from their history, optionally upgrades via a guardrailed LLM, and learns from
// the interaction.
public sealed record TutorExplainRequest(
    string TrackId,
    string LessonId,
    string ItemId,
    List<string> Selected,
    string? PublicManifestId = null);

// What the tutor knows about this learner for the concept under test, surfaced so
// the client can show "you've struggled with this before / great comeback" UX.
public sealed record TutorPersonalizationDto(
    int Attempts,
    int Errors,
    int AccuracyPct,
    bool RecurringStruggle,
    bool MasteredBefore,
    string Trend,
    string? TopConfusedOption);

public sealed record TutorExplanationDto(
    string ItemId,
    string ConceptId,
    bool Correct,
    string Headline,
    IReadOnlyList<string> Points,
    string Encouragement,
    string Recommendation,
    IReadOnlyList<string> CitedConceptIds,
    string Source,
    TutorPersonalizationDto Personalization);
