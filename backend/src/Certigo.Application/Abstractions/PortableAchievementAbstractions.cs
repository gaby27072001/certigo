using Certigo.Domain.PortableAchievements;

namespace Certigo.Application.Abstractions;

public sealed record PortableAchievementOptions(bool Enabled, string IssuerId)
{
    public static PortableAchievementOptions Disabled { get; } = new(false, "certigo");
}

public enum PortableAchievementCreateStatus
{
    Created,
    IdempotentReplay,
    EvidenceReplay,
}

public sealed record PortableAchievementCreateResult(
    PortableAchievementCreateStatus Status,
    PortableAchievementRecord Record);

public interface IPortableAchievementStore
{
    Task<PortableAchievementCreateResult> CreateAsync(
        string ownerId,
        string clientRequestId,
        string completionEvidenceId,
        PortableAchievementRecord record,
        CancellationToken cancellationToken = default);

    Task<PortableAchievementRecord?> GetAsync(
        string proofId,
        CancellationToken cancellationToken = default);

    Task<PortableAchievementRecord> AddAttestationAsync(
        string proofId,
        PortableOrganizationAttestation attestation,
        PortableAchievementAuditEntry audit,
        CancellationToken cancellationToken = default);

    Task<PortableAchievementRecord> RevokeAsync(
        string proofId,
        PortableRevocation revocation,
        PortableAchievementAuditEntry audit,
        CancellationToken cancellationToken = default);
}

public interface IPortableProofCryptography
{
    Task<PortableSigningKeyReference> GetCurrentKeyAsync(
        PortableActorType actorType,
        string actorId,
        CancellationToken cancellationToken = default);

    Task<string> SignAsync(
        PortableSigningKeyReference key,
        ReadOnlyMemory<byte> payload,
        CancellationToken cancellationToken = default);

    Task<bool> VerifyAsync(
        PortableSigningKeyReference key,
        ReadOnlyMemory<byte> payload,
        string signature,
        CancellationToken cancellationToken = default);
}

public interface IPortableNonceSource
{
    string Create();
}

public interface IPortableSubjectIdProvider
{
    Task<string> ResolveAsync(
        string internalUserId,
        CancellationToken cancellationToken = default);
}

public sealed record PortableCompletionEvidence(
    string EvidenceId,
    string InternalOwnerId,
    PortableAchievementKind Kind,
    string AchievementId,
    string ReleaseId,
    string PublicManifestId,
    DateTimeOffset CompletedAt,
    bool Successful);

public interface IPortableCompletionEvidenceResolver
{
    Task<PortableCompletionEvidence?> ResolveAsync(
        string internalUserId,
        string completionEvidenceId,
        CancellationToken cancellationToken = default);
}

public sealed record PortableActorIdentity(string ActorId, PortableActorType ActorType);

public interface IPortableActorContext
{
    Task<PortableActorIdentity> RequireAsync(
        PortableActorType expectedType,
        CancellationToken cancellationToken = default);
}

public sealed class CryptographicPortableNonceSource : IPortableNonceSource
{
    public string Create() => Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(24))
        .ToLowerInvariant();
}

public sealed class UnconfiguredPortableAchievementStore : IPortableAchievementStore
{
    private static InvalidOperationException Missing() =>
        new("Portable achievements are enabled but no durable store adapter is configured.");

    public Task<PortableAchievementCreateResult> CreateAsync(
        string ownerId,
        string clientRequestId,
        string completionEvidenceId,
        PortableAchievementRecord record,
        CancellationToken cancellationToken = default) => throw Missing();

    public Task<PortableAchievementRecord?> GetAsync(
        string proofId,
        CancellationToken cancellationToken = default) => throw Missing();

    public Task<PortableAchievementRecord> AddAttestationAsync(
        string proofId,
        PortableOrganizationAttestation attestation,
        PortableAchievementAuditEntry audit,
        CancellationToken cancellationToken = default) => throw Missing();

    public Task<PortableAchievementRecord> RevokeAsync(
        string proofId,
        PortableRevocation revocation,
        PortableAchievementAuditEntry audit,
        CancellationToken cancellationToken = default) => throw Missing();
}

public sealed class UnconfiguredPortableProofCryptography : IPortableProofCryptography
{
    private static InvalidOperationException Missing() =>
        new("Portable achievements are enabled but no managed signing-key adapter is configured.");

    public Task<PortableSigningKeyReference> GetCurrentKeyAsync(
        PortableActorType actorType,
        string actorId,
        CancellationToken cancellationToken = default) => throw Missing();

    public Task<string> SignAsync(
        PortableSigningKeyReference key,
        ReadOnlyMemory<byte> payload,
        CancellationToken cancellationToken = default) => throw Missing();

    public Task<bool> VerifyAsync(
        PortableSigningKeyReference key,
        ReadOnlyMemory<byte> payload,
        string signature,
        CancellationToken cancellationToken = default) => throw Missing();
}

public sealed class UnconfiguredPortableSubjectIdProvider : IPortableSubjectIdProvider
{
    public Task<string> ResolveAsync(
        string internalUserId,
        CancellationToken cancellationToken = default) =>
        throw new InvalidOperationException(
            "Portable achievements are enabled but no privacy-preserving subject-id adapter is configured.");
}

public sealed class UnconfiguredPortableCompletionEvidenceResolver
    : IPortableCompletionEvidenceResolver
{
    public Task<PortableCompletionEvidence?> ResolveAsync(
        string internalUserId,
        string completionEvidenceId,
        CancellationToken cancellationToken = default) =>
        throw new InvalidOperationException(
            "Portable achievements are enabled but no authoritative completion-evidence adapter is configured.");
}

public sealed class UnconfiguredPortableActorContext : IPortableActorContext
{
    public Task<PortableActorIdentity> RequireAsync(
        PortableActorType expectedType,
        CancellationToken cancellationToken = default) =>
        throw new InvalidOperationException(
            "Portable achievement administration requires a trusted actor-context adapter.");
}

public sealed class PortableAchievementsDisabledException()
    : Exception("Portable achievements are not enabled.");

public sealed class PortableAchievementConflictException(string message) : Exception(message);

public sealed class PortableAchievementNotFoundException(string proofId)
    : Exception($"Portable achievement '{proofId}' was not found.");
