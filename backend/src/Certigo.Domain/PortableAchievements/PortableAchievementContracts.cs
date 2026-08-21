using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Certigo.Domain.PortableAchievements;

public static class PortableAchievementContracts
{
    public const string CredentialV1 = "certigo.portable-achievement/v1";
    public const string OrganizationAttestationV1 = "certigo.portable-achievement-attestation/v1";
    public const string SubjectType = "Person";
    public const string IssuerType = "Platform";
}

public enum PortableAchievementKind
{
    Badge,
    Skill,
    Certification,
    Completion,
}

public enum PortableActorType
{
    Platform,
    Person,
    Organization,
}

public enum PortableRevocationReason
{
    Fraud,
    Correction,
}

public sealed record PortableSigningKeyReference(
    string KeyId,
    int Version,
    string Algorithm);

public sealed record PortableAchievementProof(
    string Schema,
    string ProofId,
    string SubjectType,
    string SubjectId,
    PortableAchievementKind Kind,
    string AchievementId,
    string CompletionEvidenceDigest,
    string ReleaseId,
    string PublicManifestId,
    DateTimeOffset CompletedAt,
    DateTimeOffset IssuedAt,
    string Nonce,
    string IssuerType,
    string IssuerId,
    PortableSigningKeyReference SigningKey,
    string Signature);

public sealed record PortableOrganizationAttestation(
    string Schema,
    string AttestationId,
    string ProofId,
    string OrganizationId,
    DateTimeOffset AttestedAt,
    PortableSigningKeyReference SigningKey,
    string Signature);

public sealed record PortableRevocation(
    PortableRevocationReason Reason,
    string Detail,
    string ActorId,
    PortableActorType ActorType,
    DateTimeOffset RevokedAt);

public sealed record PortableAchievementAuditEntry(
    string EventId,
    string EventType,
    string ActorId,
    PortableActorType ActorType,
    DateTimeOffset OccurredAt,
    string Detail);

public sealed record PortableAchievementRecord(
    PortableAchievementProof Proof,
    string RequestFingerprint,
    IReadOnlyList<PortableOrganizationAttestation> Attestations,
    PortableRevocation? Revocation,
    IReadOnlyList<PortableAchievementAuditEntry> Audit);

public static class PortableAchievementPolicy
{
    public static bool CanRevoke(PortableActorType actorType, PortableRevocationReason reason) =>
        actorType == PortableActorType.Platform
        && reason is PortableRevocationReason.Fraud or PortableRevocationReason.Correction;

    public static void ValidateProof(PortableAchievementProof? proof)
    {
        if (proof is null)
        {
            throw new ArgumentException("Proof is required.");
        }

        Require(proof.Schema, nameof(proof.Schema), PortableAchievementContracts.CredentialV1);
        Require(proof.ProofId, nameof(proof.ProofId));
        Require(proof.SubjectType, nameof(proof.SubjectType), PortableAchievementContracts.SubjectType);
        Require(proof.SubjectId, nameof(proof.SubjectId));
        Require(proof.AchievementId, nameof(proof.AchievementId));
        Require(proof.CompletionEvidenceDigest, nameof(proof.CompletionEvidenceDigest));
        Require(proof.ReleaseId, nameof(proof.ReleaseId));
        Require(proof.PublicManifestId, nameof(proof.PublicManifestId));
        Require(proof.Nonce, nameof(proof.Nonce));
        Require(proof.IssuerType, nameof(proof.IssuerType), PortableAchievementContracts.IssuerType);
        Require(proof.IssuerId, nameof(proof.IssuerId));
        if (proof.SigningKey is null)
        {
            throw new ArgumentException("Signing key reference is required.");
        }

        Require(proof.SigningKey.KeyId, nameof(proof.SigningKey.KeyId));
        Require(proof.SigningKey.Algorithm, nameof(proof.SigningKey.Algorithm));
        Require(proof.Signature, nameof(proof.Signature));

        if (proof.SigningKey.Version <= 0)
        {
            throw new ArgumentException("Signing key version must be positive.");
        }

        if (proof.CompletedAt > proof.IssuedAt)
        {
            throw new ArgumentException("Completion time cannot be after issuance time.");
        }
    }

    private static void Require(string value, string name, string? expected = null)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 256)
        {
            throw new ArgumentException($"{name} is required and must not exceed 256 characters.");
        }

        if (expected is not null && !string.Equals(value, expected, StringComparison.Ordinal))
        {
            throw new ArgumentException($"{name} must be '{expected}'.");
        }
    }
}

public static class PortableAchievementCanonicalizer
{
    public static byte[] Canonicalize(PortableAchievementProof proof)
    {
        using var stream = new MemoryStream();
        using var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = false });
        writer.WriteStartObject();
        writer.WriteString("achievementId", proof.AchievementId);
        writer.WriteString("completedAt", proof.CompletedAt);
        writer.WriteString("completionEvidenceDigest", proof.CompletionEvidenceDigest);
        writer.WriteString("issuerId", proof.IssuerId);
        writer.WriteString("issuerType", proof.IssuerType);
        writer.WriteString("issuedAt", proof.IssuedAt);
        writer.WriteString("kind", proof.Kind.ToString().ToLowerInvariant());
        writer.WriteString("nonce", proof.Nonce);
        writer.WriteString("proofId", proof.ProofId);
        writer.WriteString("publicManifestId", proof.PublicManifestId);
        writer.WriteString("releaseId", proof.ReleaseId);
        writer.WriteString("schema", proof.Schema);
        writer.WriteStartObject("signingKey");
        writer.WriteString("algorithm", proof.SigningKey.Algorithm);
        writer.WriteString("keyId", proof.SigningKey.KeyId);
        writer.WriteNumber("version", proof.SigningKey.Version);
        writer.WriteEndObject();
        writer.WriteString("subjectId", proof.SubjectId);
        writer.WriteString("subjectType", proof.SubjectType);
        writer.WriteEndObject();
        writer.Flush();
        return stream.ToArray();
    }

    public static string Sha256(string value)
    {
        var digest = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        return $"sha256:{Convert.ToHexString(digest).ToLowerInvariant()}";
    }
}
