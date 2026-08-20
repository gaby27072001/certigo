using System.Security.Cryptography;
using System.Text;
using Certigo.Domain.Identity;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class PersonLinkedIdentityTests
{
    private const string Tenant = "11111111-1111-4111-8111-aaaaaaaaaaaa";
    private const string ObjectId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

    [Fact]
    public void Locator_id_matches_the_versioned_contract_and_is_deterministic()
    {
        var locator = new IdentityLocator(
            IdentityLocator.EntraProvider,
            Tenant,
            ObjectId,
            IdentityLocator.EntraExternalIdType);
        var material = string.Join(
            "\0",
            "certigo-linked-identity:v1",
            IdentityLocator.EntraProvider,
            Tenant,
            ObjectId,
            IdentityLocator.EntraExternalIdType);
        var expectedHash = Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(material)))
            .ToLowerInvariant();

        locator.StableId().Should().Be($"linked-identity::v1::{expectedHash}");
        locator.StableId().Should().Be(locator.StableId());
    }

    [Theory]
    [InlineData("entra-external-id ", Tenant, ObjectId, "entraExternalId")]
    [InlineData("entra-external-id", "11111111-1111-4111-8111-AAAAAAAAAAAA", ObjectId, "entraExternalId")]
    [InlineData("certigo-local", "certigo", "ABCDEF0123456789ABCDEF0123456789", "localPassword")]
    [InlineData("certigo-local", "certigo", "abcdef0123456789abcdef0123456789", "entraExternalId")]
    public void Locator_rejects_ambiguous_or_mismatched_values(
        string provider,
        string tenant,
        string subject,
        string type)
    {
        var action = () => new IdentityLocator(provider, tenant, subject, type)
            .EnsureCanonical();

        action.Should().Throw<InvalidIdentityLocatorException>();
    }

    [Fact]
    public void Shadow_metadata_keeps_person_and_legacy_user_ids_equal()
    {
        var metadata = PersonIdentityMetadata.Shadow(
            "legacy-user",
            new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero));

        metadata.PersonId.Should().Be("legacy-user");
        metadata.LegacyUserId.Should().Be("legacy-user");
        metadata.MigrationState.Should().Be(PersonIdentityMetadata.ShadowMigrationState);
        metadata.Invoking(value => value.EnsureConsistentWith("legacy-user"))
            .Should().NotThrow();
        metadata.Invoking(value => value.EnsureConsistentWith("another-user"))
            .Should().Throw<PersonIdentityIntegrityException>();
    }

    [Fact]
    public void Intent_and_operation_idempotency_are_scoped_by_person()
    {
        var intentA = IdentityLinkIntent.IdFor("person-a", "same-key");
        var intentB = IdentityLinkIntent.IdFor("person-b", "same-key");
        var operationA = IdentityLinkOperation.IdFor("person-a", "same-key");
        var operationB = IdentityLinkOperation.IdFor("person-b", "same-key");

        intentA.Should().NotBe(intentB);
        operationA.Should().NotBe(operationB);
        intentA.Should().StartWith("identity-link-intent::v1::");
        operationA.Should().StartWith("identity-link-operation::v1::");
    }
}
