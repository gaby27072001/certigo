using Certigo.Domain.PortableAchievements;

namespace Certigo.Application.Dtos;

public sealed record IssuePortableAchievementRequest(
    string ClientRequestId,
    string CompletionEvidenceId);

public sealed record IssuePortableAchievementResult(
    PortableAchievementProof Proof,
    bool IdempotentReplay);

public sealed record PortableRevocationStatus(
    PortableRevocationReason Reason,
    DateTimeOffset RevokedAt);

public sealed record PortableAchievementView(
    PortableAchievementProof Proof,
    IReadOnlyList<PortableOrganizationAttestation> Attestations,
    PortableRevocationStatus? Revocation);

public sealed record VerifyPortableAchievementRequest(PortableAchievementProof? Proof);

public sealed record VerifyPortableAchievementResult(
    bool Valid,
    bool Revoked,
    string? FailureCode,
    PortableRevocationStatus? Revocation);

public sealed record AttestPortableAchievementCommand(
    string ProofId,
    string AttestationId);

public sealed record RevokePortableAchievementCommand(
    string ProofId,
    PortableRevocationReason Reason,
    string Detail);
