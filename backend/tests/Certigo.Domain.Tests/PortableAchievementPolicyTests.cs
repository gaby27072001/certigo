using Certigo.Domain.PortableAchievements;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class PortableAchievementPolicyTests
{
    [Theory]
    [InlineData(PortableActorType.Organization)]
    [InlineData(PortableActorType.Person)]
    public void Personal_achievement_cannot_be_revoked_by_non_platform_actor(
        PortableActorType actorType)
    {
        PortableAchievementPolicy.CanRevoke(actorType, PortableRevocationReason.Fraud)
            .Should().BeFalse();
    }

    [Theory]
    [InlineData(PortableRevocationReason.Fraud)]
    [InlineData(PortableRevocationReason.Correction)]
    public void Platform_can_revoke_only_for_auditable_allowed_reasons(
        PortableRevocationReason reason)
    {
        PortableAchievementPolicy.CanRevoke(PortableActorType.Platform, reason)
            .Should().BeTrue();
    }

    [Fact]
    public void Canonical_payload_is_stable_and_excludes_signature()
    {
        var proof = Proof("signature-one");
        var changedSignature = proof with { Signature = "signature-two" };

        PortableAchievementCanonicalizer.Canonicalize(proof)
            .Should().Equal(PortableAchievementCanonicalizer.Canonicalize(changedSignature));
    }

    private static PortableAchievementProof Proof(string signature) =>
        new(
            PortableAchievementContracts.CredentialV1,
            "proof_1",
            PortableAchievementContracts.SubjectType,
            "person_1",
            PortableAchievementKind.Skill,
            "skill_1",
            "sha256:evidence",
            "sha256:release",
            "sha256:manifest",
            new DateTimeOffset(2026, 8, 20, 10, 0, 0, TimeSpan.Zero),
            new DateTimeOffset(2026, 8, 20, 11, 0, 0, TimeSpan.Zero),
            "nonce",
            PortableAchievementContracts.IssuerType,
            "certigo",
            new PortableSigningKeyReference("proofs", 1, "HS256-test-only"),
            signature);
}
