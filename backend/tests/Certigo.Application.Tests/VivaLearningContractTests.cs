using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class VivaLearningContractTests
{
    private static readonly VivaLearningContentFixtureDto Fixture = new(
        "22222222-2222-2222-2222-222222222222",
        "az-900",
        "az900-l-cloud-benefits",
        "Benefices du cloud",
        "Fixture-only learning content.",
        "fr-fr",
        5,
        "Course",
        "Beginner",
        "Certigo",
        true,
        true,
        true);

    [Fact]
    public void Feature_contract_is_off_only_and_defaults_to_a_non_routable_origin()
    {
        var options = VivaLearningFeatureOptions.Parse(null, null);

        options.Mode.Should().Be(VivaLearningFeatureMode.Off);
        options.PublicWebOrigin.Should().Be(new Uri("https://links-disabled.invalid/"));
        FluentActions.Invoking(() => VivaLearningFeatureOptions.Parse("on", null))
            .Should()
            .Throw<InvalidOperationException>();
    }

    [Theory]
    [InlineData("https://localhost/")]
    [InlineData("http://example.invalid/")]
    [InlineData("https://example.invalid:444/")]
    [InlineData("https://example.invalid/path")]
    public void Public_origin_rejects_routable_or_ambiguous_values(string value)
    {
        FluentActions.Invoking(() => VivaLearningFeatureOptions.ParseFixtureOrigin(value))
            .Should()
            .Throw<InvalidOperationException>();
    }

    [Fact]
    public void Permission_catalog_preserves_endpoint_specific_auth_boundaries()
    {
        VivaLearningPermissionContract.All.Should().BeEquivalentTo(
            [
                new
                {
                    Operation = "Register provider",
                    AuthMode = VivaLearningAuthMode.DelegatedAdministrator,
                    Permission = "LearningProvider.ReadWrite",
                },
                new
                {
                    Operation = "Publish content",
                    AuthMode = VivaLearningAuthMode.Application,
                    Permission = "LearningContent.ReadWrite.All",
                },
                new
                {
                    Operation = "Read my assignments",
                    AuthMode = VivaLearningAuthMode.DelegatedUser,
                    Permission = "LearningAssignedCourse.Read.All",
                },
                new
                {
                    Operation = "Sync assignment progress",
                    AuthMode = VivaLearningAuthMode.Application,
                    Permission = "LearningAssignedCourse.ReadWrite.All",
                },
            ],
            options => options.WithStrictOrdering());
    }

    [Fact]
    public void Organization_mapping_is_idempotent_and_tenant_isolated()
    {
        var origin = new Uri("https://catalog.invalid/");

        var first = VivaLearningOrganizationMapper.Map("organization-a", Fixture, origin);
        var replay = VivaLearningOrganizationMapper.Map("organization-a", Fixture, origin);
        var otherOrganization =
            VivaLearningOrganizationMapper.Map("organization-b", Fixture, origin);

        replay.Should().Be(first);
        otherOrganization.ExternalId.Should().NotBe(first.ExternalId);
        otherOrganization.OrganizationId.Should().Be("organization-b");
        first.ExternalId.Should().StartWith("certigo:");
        first.ContentWebUrl.Should()
            .Be("https://catalog.invalid/learn/az-900/az900-l-cloud-benefits");
    }

    [Fact]
    public void Enterprise_contracts_do_not_mix_person_or_personal_learning_data()
    {
        var names = new[]
            {
                typeof(VivaLearningTenantConsent),
                typeof(EncryptedTokenEnvelope),
                typeof(VivaLearningTokenCacheKey),
                typeof(VivaLearningContentDto),
            }
            .SelectMany(type => type.GetProperties())
            .Select(property => property.Name)
            .ToArray();

        names.Should().NotContain(name =>
            name.Contains("Email", StringComparison.OrdinalIgnoreCase)
            || name.Contains("Person", StringComparison.OrdinalIgnoreCase)
            || name.Contains("Mastery", StringComparison.OrdinalIgnoreCase)
            || name.Contains("Readiness", StringComparison.OrdinalIgnoreCase)
            || name.Equals("Token", StringComparison.OrdinalIgnoreCase));
        names.Should().Contain(nameof(VivaLearningContentDto.OrganizationId));
        names.Should().Contain(nameof(EncryptedTokenEnvelope.Ciphertext));
    }

    [Fact]
    public void Delegated_token_cache_keys_are_subject_scoped_without_email_correlation()
    {
        var first = new VivaLearningTokenCacheKey(
            "organization-a",
            "enterprise-tenant",
            VivaLearningAuthMode.DelegatedUser,
            "opaque-subject-a");
        var second = first with { EnterpriseSubjectId = "opaque-subject-b" };
        var application = new VivaLearningTokenCacheKey(
            "organization-a",
            "enterprise-tenant",
            VivaLearningAuthMode.Application,
            null);

        first.Invoking(key => key.EnsureValid()).Should().NotThrow();
        second.Invoking(key => key.EnsureValid()).Should().NotThrow();
        application.Invoking(key => key.EnsureValid()).Should().NotThrow();
        first.Should().NotBe(second);

        (first with { EnterpriseSubjectId = null })
            .Invoking(key => key.EnsureValid())
            .Should()
            .Throw<ArgumentException>();
        (application with { EnterpriseSubjectId = "unexpected-subject" })
            .Invoking(key => key.EnsureValid())
            .Should()
            .Throw<ArgumentException>();
    }
}
