using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class EnterpriseIdentityModelsTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 31, 8, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Domain_claim_is_global_and_cannot_be_rebound_to_another_tenant()
    {
        var first = EnterpriseDomainVerification.Create(
            "organization-a",
            "EXAMPLE.COM.",
            "domain-request-0001",
            Secret('a'),
            Now);
        var takeover = EnterpriseDomainVerification.Create(
            "organization-b",
            "example.com",
            "domain-request-0002",
            Secret('b'),
            Now);

        first.Id.Should().Be(takeover.Id);
        first.CanonicalDomain.Should().Be("example.com");
        first.Invoking(value => value.EnsureOrganization("organization-b"))
            .Should().Throw<OrganizationNotFoundException>();
        var claim = EnterpriseDomainClaim.Create(first);
        claim.Invoking(value => value.EnsureOwnedBy("organization-b"))
            .Should().Throw<EnterpriseDomainAlreadyClaimedException>();
        claim.ToString().Should().NotContain("organization-a");
    }

    [Fact]
    public void Domain_challenge_is_single_use_and_never_persists_plaintext()
    {
        var challenge = Secret('a');
        var pending = EnterpriseDomainVerification.Create(
            "organization-a",
            "example.com",
            "domain-request-0001",
            challenge,
            Now);

        var verified = pending.Verify("organization-a", challenge, Now.AddMinutes(1));

        verified.Status.Should().Be(EnterpriseDomainStatus.Verified);
        verified.ToString().Should().NotContain(challenge);
        verified.Invoking(value => value.Verify(
                "organization-a",
                challenge,
                Now.AddMinutes(2)))
            .Should().Throw<EnterpriseReplayException>();
    }

    [Fact]
    public void Scim_token_rotation_hashes_tokens_and_limits_previous_generation_overlap()
    {
        var firstToken = Secret('a');
        var secondToken = Secret('b');
        var credential = ScimTokenCredential.Create("organization-a", firstToken, Now)
            with
        { ETag = "\"1\"" };
        var rotated = credential.Rotate(
            "organization-a",
            secondToken,
            Now.AddHours(1),
            TimeSpan.FromMinutes(15));

        rotated.ToString().Should().NotContain(firstToken).And.NotContain(secondToken);
        rotated.Generation.Should().Be(2);
        rotated.Authenticates("organization-a", firstToken, Now.AddHours(1).AddMinutes(14))
            .Should().BeTrue();
        rotated.Authenticates("organization-a", firstToken, Now.AddHours(1).AddMinutes(15))
            .Should().BeFalse();
        rotated.Authenticates("organization-a", secondToken, Now.AddDays(1)).Should().BeTrue();
        rotated.Authenticates(
                "organization-a",
                secondToken,
                Now.AddDays(91))
            .Should().BeFalse();
        rotated.Invoking(value => value.Authenticates(
                "organization-b",
                secondToken,
                Now))
            .Should().Throw<OrganizationNotFoundException>();
        var persisted = rotated with { ETag = "\"2\"" };
        var revoked = persisted.Revoke("organization-a", Now.AddHours(2));
        revoked.Authenticates("organization-a", secondToken, Now.AddHours(3)).Should().BeFalse();
    }

    [Theory]
    [InlineData(OrganizationRole.Owner)]
    [InlineData(OrganizationRole.Admin)]
    public void Scim_cannot_escalate_a_provisioned_user_to_privileged_roles(
        OrganizationRole role)
    {
        var action = () => ScimProvisionedUser.Create(
            "organization-a",
            "external-1",
            "person@example.test",
            role,
            "scim-request-00001",
            Now);

        action.Should().Throw<OrganizationAccessDeniedException>();
    }

    [Fact]
    public void Provisioning_does_not_bind_or_merge_a_person_by_email()
    {
        var user = ScimProvisionedUser.Create(
            "organization-a",
            "external-1",
            "shared@example.test",
            OrganizationRole.Learner,
            "scim-request-00001",
            Now);

        user.PersonId.Should().BeNull();
        user.LinkedIdentityId.Should().BeNull();
        user.ToString().Should().NotContain("shared@example.test");
    }

    [Fact]
    public void Deprovision_wins_a_race_with_late_identity_binding_and_is_idempotent()
    {
        var user = ScimProvisionedUser.Create(
            "organization-a",
            "external-1",
            "person@example.test",
            OrganizationRole.Learner,
            "scim-request-00001",
            Now);
        user = user with { ETag = "\"1\"" };
        var deprovisioned = user.Deprovision("organization-a", Now.AddMinutes(1));

        deprovisioned.Deprovision("organization-a", Now.AddMinutes(2))
            .Should().Be(deprovisioned);
        deprovisioned.Invoking(value => value.Bind(
                "organization-a",
                "person-1",
                "linked-identity-1",
                Now.AddMinutes(2)))
            .Should().Throw<EnterpriseReplayException>();
    }

    [Fact]
    public void Bound_user_deprovision_produces_one_cas_plan_for_membership_and_tombstone()
    {
        var staged = ScimProvisionedUser.Create(
                "organization-a",
                "external-1",
                "person@example.test",
                OrganizationRole.Learner,
                "scim-request-00001",
                Now)
            with
        { ETag = "\"user-1\"" };
        var bound = staged.Bind(
                "organization-a",
                "person-1",
                "linked-identity-1",
                Now.AddMinutes(1))
            with
        { ETag = "\"user-2\"" };
        var membership = OrganizationMembership.Create(
                "organization-a",
                "person-1",
                OrganizationRole.Learner,
                Now)
            with
        { ETag = "\"membership-1\"" };

        var plan = bound.PlanDeprovision(
            "organization-a",
            membership,
            Now.AddMinutes(2));

        plan.ExpectedDirectoryUserETag.Should().Be("\"user-2\"");
        plan.ExpectedMembershipETag.Should().Be("\"membership-1\"");
        plan.DirectoryUser.Active.Should().BeFalse();
        plan.DirectoryUser.PersonId.Should().BeNull();
        plan.DirectoryUser.LinkedIdentityId.Should().BeNull();
        plan.Tombstone.TargetMembershipId.Should().Be(membership.Id);
        bound.Invoking(value => value.Deprovision(
                "organization-a",
                Now.AddMinutes(2)))
            .Should().Throw<EnterpriseAtomicOffboardingRequiredException>();
    }

    [Fact]
    public void Audit_event_contains_only_tenant_scoped_pseudonyms()
    {
        var audit = EnterpriseAuditEvent.Create(
            "organization-a",
            EnterpriseAuditAction.ScimUserProvisioned,
            "admin@example.test",
            "person@example.test",
            "succeeded",
            Now);

        audit.ToString().Should().NotContain("@example.test");
        audit.ActorHash.Should().HaveLength(64);
        audit.TargetHash.Should().HaveLength(64);
    }

    [Fact]
    public void Federation_contract_accepts_only_abstract_https_metadata_without_secrets()
    {
        var connection = EnterpriseFederationConnection.Create(
            "organization-a",
            EnterpriseFederationProtocol.Saml,
            "https://idp.example.test/entity",
            "certigo",
            "https://idp.example.test/metadata",
            Now);

        connection.Enabled.Should().BeFalse();
        connection.ToString().Should().NotContain("secret");
        var invalid = () => EnterpriseFederationConnection.Create(
            "organization-a",
            EnterpriseFederationProtocol.Oidc,
            "issuer",
            "certigo",
            "http://idp.example.test/.well-known/openid-configuration",
            Now);
        invalid.Should().Throw<EnterpriseIdentityValidationException>();
    }

    [Fact]
    public void Scim_group_members_are_tenant_scoped_hashes_not_external_identifiers()
    {
        var group = ScimProvisionedGroup.Create(
            "organization-a",
            "group-1",
            "Security training",
            ["external-user-1", "external-user-1"],
            "group-request-0001",
            Now);

        group.MemberExternalIdHashes.Should().ContainSingle();
        group.ToString().Should().NotContain("external-user-1");
    }

    private static string Secret(char value) => new(value, 64);
}
