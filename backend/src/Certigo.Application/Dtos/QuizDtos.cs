using Certigo.Domain.Content;

namespace Certigo.Application.Dtos;

public sealed record SubmitQuizRequest(
    string ClientAttemptId,
    string TrackId,
    DateTimeOffset StartedAt,
    List<AnswerDto> Answers);

public sealed record AnswerDto(
    string ItemId,
    ItemType ItemType,
    List<string> Selected,
    int LatencyMs);

public sealed record SubmitQuizResult(
    string AttemptId,
    int ScorePct,
    List<ItemResultDto> Results,
    RewardsDto Rewards,
    List<string> WeakConcepts,
    DateTimeOffset? NextReviewDueAt);

public sealed record ItemResultDto(
    string ItemId,
    bool Correct,
    string ConceptId,
    List<string>? CorrectAnswer,
    string Explanation,
    double MasteryDelta);

public sealed record RewardsDto(
    int XpEarned,
    int NewXp,
    bool LevelUp,
    bool StreakExtended,
    int GemsEarned,
    List<string> AchievementsUnlocked);

// Charge utile de l'événement `attempt.flagged` émis par l'anti-triche en mode
// détection. Schéma stable et typé (plutôt qu'anonyme) pour être sérialisable,
// testable et exploitable par l'observabilité. `ReferenceId` = lessonId (quiz)
// ou examId (examen). Aucune récompense n'est modifiée à l'émission.
public sealed record AttemptIntegritySignal(
    string Kind,
    string ReferenceId,
    string AttemptId,
    string Decision,
    double RiskScore,
    List<string> Flags);
