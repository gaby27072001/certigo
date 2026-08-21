using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.PortableAchievements;

namespace Certigo.Application.Services;

public interface IPortableAchievementService
{
    Task<IssuePortableAchievementResult> IssueAsync(
        IssuePortableAchievementRequest request,
        CancellationToken cancellationToken = default);

    Task<PortableAchievementView> GetAsync(
        string proofId,
        CancellationToken cancellationToken = default);

    Task<VerifyPortableAchievementResult> VerifyAsync(
        VerifyPortableAchievementRequest request,
        CancellationToken cancellationToken = default);
}

public interface IPortableAchievementAdministrationService
{
    Task<PortableAchievementRecord> AttestAsync(
        AttestPortableAchievementCommand command,
        CancellationToken cancellationToken = default);

    Task<PortableAchievementRecord> RevokeAsync(
        RevokePortableAchievementCommand command,
        CancellationToken cancellationToken = default);
}

public sealed class PortableAchievementService(
    PortableAchievementOptions options,
    IUserContext userContext,
    IClock clock,
    IPortableAchievementStore store,
    IPortableProofCryptography cryptography,
    IPortableNonceSource nonces,
    IPortableSubjectIdProvider subjectIds,
    IPortableCompletionEvidenceResolver completionEvidence,
    IPortableActorContext actorContext)
    : IPortableAchievementService, IPortableAchievementAdministrationService
{
    public async Task<IssuePortableAchievementResult> IssueAsync(
        IssuePortableAchievementRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        ValidateIssueRequest(request);

        var issuedAt = clock.UtcNow;
        var evidence = await completionEvidence.ResolveAsync(
            userContext.UserId,
            request.CompletionEvidenceId,
            cancellationToken)
            ?? throw new RequestValidationException(
                "The completion evidence does not exist for the authenticated person.");
        ValidateCompletionEvidence(evidence, userContext.UserId, issuedAt);
        var publicSubjectId = await subjectIds.ResolveAsync(userContext.UserId, cancellationToken);
        Require(publicSubjectId, "portableSubjectId");
        var key = await cryptography.GetCurrentKeyAsync(
            PortableActorType.Platform,
            options.IssuerId,
            cancellationToken);
        var unsigned = new PortableAchievementProof(
            PortableAchievementContracts.CredentialV1,
            $"proof_{nonces.Create()}",
            PortableAchievementContracts.SubjectType,
            publicSubjectId,
            evidence.Kind,
            evidence.AchievementId,
            PortableAchievementCanonicalizer.Sha256(evidence.EvidenceId),
            evidence.ReleaseId,
            evidence.PublicManifestId,
            evidence.CompletedAt,
            issuedAt,
            nonces.Create(),
            PortableAchievementContracts.IssuerType,
            options.IssuerId,
            key,
            string.Empty);
        var signature = await cryptography.SignAsync(
            key,
            PortableAchievementCanonicalizer.Canonicalize(unsigned),
            cancellationToken);
        var proof = unsigned with { Signature = signature };
        PortableAchievementPolicy.ValidateProof(proof);

        var fingerprint = Fingerprint(request, evidence);
        var audit = new PortableAchievementAuditEntry(
            $"audit_{nonces.Create()}",
            "issued",
            options.IssuerId,
            PortableActorType.Platform,
            issuedAt,
            $"kind={evidence.Kind};achievement={evidence.AchievementId}");
        var candidate = new PortableAchievementRecord(
            proof,
            fingerprint,
            [],
            null,
            [audit]);
        var created = await store.CreateAsync(
            userContext.UserId,
            request.ClientRequestId,
            evidence.EvidenceId,
            candidate,
            cancellationToken);

        if (created.Status == PortableAchievementCreateStatus.EvidenceReplay)
        {
            throw new PortableAchievementConflictException(
                "This completion evidence has already been used for a portable achievement.");
        }

        if (!string.Equals(created.Record.RequestFingerprint, fingerprint, StringComparison.Ordinal))
        {
            throw new PortableAchievementConflictException(
                "The idempotency key was already used with a different request.");
        }

        return new IssuePortableAchievementResult(
            created.Record.Proof,
            created.Status == PortableAchievementCreateStatus.IdempotentReplay);
    }

    public async Task<PortableAchievementView> GetAsync(
        string proofId,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        var record = await store.GetAsync(proofId, cancellationToken)
            ?? throw new PortableAchievementNotFoundException(proofId);
        return ToView(record);
    }

    public async Task<VerifyPortableAchievementResult> VerifyAsync(
        VerifyPortableAchievementRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        try
        {
            PortableAchievementPolicy.ValidateProof(request.Proof);
        }
        catch (ArgumentException)
        {
            return new VerifyPortableAchievementResult(false, false, "invalidContract", null);
        }

        var proof = request.Proof!;
        var stored = await store.GetAsync(proof.ProofId, cancellationToken);
        if (stored is null
            || !string.Equals(
                stored.Proof.IssuerType,
                PortableAchievementContracts.IssuerType,
                StringComparison.Ordinal)
            || !string.Equals(stored.Proof.IssuerId, options.IssuerId, StringComparison.Ordinal)
            || !string.Equals(
                PortableAchievementCanonicalizer.Sha256(Convert.ToBase64String(
                    PortableAchievementCanonicalizer.Canonicalize(stored.Proof))),
                PortableAchievementCanonicalizer.Sha256(Convert.ToBase64String(
                    PortableAchievementCanonicalizer.Canonicalize(proof))),
                StringComparison.Ordinal)
            || !string.Equals(stored.Proof.Signature, proof.Signature, StringComparison.Ordinal))
        {
            return new VerifyPortableAchievementResult(false, false, "unknownProof", null);
        }

        var validSignature = await cryptography.VerifyAsync(
            stored.Proof.SigningKey,
            PortableAchievementCanonicalizer.Canonicalize(stored.Proof),
            stored.Proof.Signature,
            cancellationToken);
        if (!validSignature)
        {
            return new VerifyPortableAchievementResult(false, false, "invalidSignature", null);
        }

        return stored.Revocation is null
            ? new VerifyPortableAchievementResult(true, false, null, null)
            : new VerifyPortableAchievementResult(
                false,
                true,
                "revoked",
                new PortableRevocationStatus(
                    stored.Revocation.Reason,
                    stored.Revocation.RevokedAt));
    }

    public async Task<PortableAchievementRecord> AttestAsync(
        AttestPortableAchievementCommand command,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        _ = await store.GetAsync(command.ProofId, cancellationToken)
            ?? throw new PortableAchievementNotFoundException(command.ProofId);
        Require(command.AttestationId, nameof(command.AttestationId));
        var actor = await actorContext.RequireAsync(
            PortableActorType.Organization,
            cancellationToken);

        var now = clock.UtcNow;
        var key = await cryptography.GetCurrentKeyAsync(
            PortableActorType.Organization,
            actor.ActorId,
            cancellationToken);
        var payload = System.Text.Encoding.UTF8.GetBytes(
            $"{PortableAchievementContracts.OrganizationAttestationV1}\n{command.AttestationId}\n"
            + $"{command.ProofId}\n{actor.ActorId}\n{now:O}\n"
            + $"{key.KeyId}\n{key.Version}\n{key.Algorithm}");
        var signature = await cryptography.SignAsync(key, payload, cancellationToken);
        var attestation = new PortableOrganizationAttestation(
            PortableAchievementContracts.OrganizationAttestationV1,
            command.AttestationId,
            command.ProofId,
            actor.ActorId,
            now,
            key,
            signature);
        var audit = new PortableAchievementAuditEntry(
            $"audit_{nonces.Create()}",
            "organizationAttested",
            actor.ActorId,
            PortableActorType.Organization,
            now,
            $"attestation={command.AttestationId}");
        return await store.AddAttestationAsync(command.ProofId, attestation, audit, cancellationToken);
    }

    public async Task<PortableAchievementRecord> RevokeAsync(
        RevokePortableAchievementCommand command,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        var actor = await actorContext.RequireAsync(
            PortableActorType.Platform,
            cancellationToken);
        if (!PortableAchievementPolicy.CanRevoke(actor.ActorType, command.Reason))
        {
            throw new PortableAchievementConflictException(
                "Only the platform may revoke a personal achievement, and only for fraud or correction.");
        }

        Require(command.Detail, nameof(command.Detail));
        var now = clock.UtcNow;
        var revocation = new PortableRevocation(
            command.Reason,
            command.Detail,
            actor.ActorId,
            actor.ActorType,
            now);
        var audit = new PortableAchievementAuditEntry(
            $"audit_{nonces.Create()}",
            "revoked",
            actor.ActorId,
            actor.ActorType,
            now,
            $"reason={command.Reason};detail={command.Detail}");
        return await store.RevokeAsync(command.ProofId, revocation, audit, cancellationToken);
    }

    private void EnsureEnabled()
    {
        if (!options.Enabled)
        {
            throw new PortableAchievementsDisabledException();
        }
    }

    private static void ValidateIssueRequest(IssuePortableAchievementRequest request)
    {
        Require(request.ClientRequestId, nameof(request.ClientRequestId));
        Require(request.CompletionEvidenceId, nameof(request.CompletionEvidenceId));
    }

    private static void ValidateCompletionEvidence(
        PortableCompletionEvidence evidence,
        string expectedOwnerId,
        DateTimeOffset issuedAt)
    {
        if (!evidence.Successful
            || !string.Equals(evidence.InternalOwnerId, expectedOwnerId, StringComparison.Ordinal))
        {
            throw new RequestValidationException(
                "The completion evidence is not an eligible successful completion for the authenticated person.");
        }

        Require(evidence.EvidenceId, nameof(evidence.EvidenceId));
        Require(evidence.AchievementId, nameof(evidence.AchievementId));
        Require(evidence.ReleaseId, nameof(evidence.ReleaseId));
        Require(evidence.PublicManifestId, nameof(evidence.PublicManifestId));
        if (evidence.CompletedAt > issuedAt)
        {
            throw new RequestValidationException("Completion evidence cannot be dated in the future.");
        }
    }

    private static string Fingerprint(
        IssuePortableAchievementRequest request,
        PortableCompletionEvidence evidence) =>
        PortableAchievementCanonicalizer.Sha256(
            $"{evidence.InternalOwnerId}\n{evidence.Kind}\n{evidence.AchievementId}\n"
            + $"{request.ClientRequestId}\n{evidence.EvidenceId}\n{evidence.ReleaseId}\n"
            + $"{evidence.PublicManifestId}\n{evidence.CompletedAt:O}");

    private static PortableAchievementView ToView(PortableAchievementRecord record) =>
        new(
            record.Proof,
            record.Attestations,
            record.Revocation is null
                ? null
                : new PortableRevocationStatus(
                    record.Revocation.Reason,
                    record.Revocation.RevokedAt));

    private static void Require(string value, string name)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 256)
        {
            throw new RequestValidationException(
                $"{name} is required and must not exceed 256 characters.");
        }
    }
}
