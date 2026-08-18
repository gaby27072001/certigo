using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class CertificationCatalogTests
{
    [Fact]
    public void Embedded_catalog_contains_the_exact_active_AWS_and_GCP_inventory()
    {
        var registry = new EmbeddedCertificationRegistry();

        registry.Version.Should().Be("2026-08-17");
        registry.Entries.Should().HaveCount(26);
        registry.Entries.Should().OnlyContain(entry => entry.Status == "active");
        registry.Entries.Should().OnlyContain(entry => entry.ContentStatus == "planned");
        registry.Entries.Select(entry => entry.Id).Should().OnlyHaveUniqueItems();

        var aws = registry.Entries.Where(entry => entry.Provider == "aws").ToArray();
        aws.Should().HaveCount(12);
        aws.Should().OnlyContain(entry => !string.IsNullOrWhiteSpace(entry.Code));
        aws.Count(entry => entry.Level == "foundational").Should().Be(2);
        aws.Count(entry => entry.Level == "associate").Should().Be(5);
        aws.Count(entry => entry.Level == "professional").Should().Be(3);
        aws.Count(entry => entry.Level == "specialty").Should().Be(2);
        aws.Single(entry => entry.Code == "ANS-C01").RetiresOn.Should().Be(new DateOnly(2026, 8, 25));

        var gcp = registry.Entries.Where(entry => entry.Provider == "gcp").ToArray();
        gcp.Should().HaveCount(14);
        gcp.Should().OnlyContain(entry => string.IsNullOrEmpty(entry.Code));
        gcp.Count(entry => entry.Level == "foundational").Should().Be(2);
        gcp.Count(entry => entry.Level == "associate").Should().Be(3);
        gcp.Count(entry => entry.Level == "professional").Should().Be(9);
        gcp.Should().NotContain(entry => entry.Level == "specialty");
        gcp.Single(entry => entry.Id == "gcp-professional-data-engineer")
            .BlueprintVersion.Should().Be("v4.2");
        gcp.Single(entry => entry.Id == "gcp-professional-cloud-database-engineer")
            .BlueprintVersion.Should().Be("v1.2");
    }

    [Fact]
    public void Validator_accepts_a_retired_entry_with_an_official_url_and_retirement_date()
    {
        var document = new CertificationCatalogDocument(
            SchemaVersion: 1,
            AsOf: new DateOnly(2026, 8, 17),
            Sources: new[] { "https://aws.amazon.com/certification/" },
            Certifications: new[]
            {
                new CertificationCatalogEntry(
                    Id: "aws-retired-test",
                    Provider: "aws",
                    Family: "security",
                    Code: "TST-C01",
                    Title: "Retired test certification",
                    Level: "specialty",
                    Status: "retired",
                    ContentStatus: "planned",
                    OfficialUrl: "https://aws.amazon.com/certification/",
                    RetiredOn: new DateOnly(2026, 1, 1)),
            });

        CertificationCatalogValidator.Validate(document).Should().BeEmpty();
    }

    [Fact]
    public void Validator_rejects_duplicates_unknown_providers_and_non_official_urls()
    {
        var invalid = new CertificationCatalogEntry(
            Id: "aws-invalid",
            Provider: "azure",
            Family: "Security",
            Code: "BAD",
            Title: "Invalid",
            Level: "expert",
            Status: "active",
            ContentStatus: "available",
            OfficialUrl: "http://example.com/certification");
        var document = new CertificationCatalogDocument(
            SchemaVersion: 1,
            AsOf: new DateOnly(2026, 8, 17),
            Sources: new[] { "https://aws.amazon.com/certification/" },
            Certifications: new[] { invalid, invalid });

        var errors = CertificationCatalogValidator.Validate(document);

        errors.Should().Contain(error => error.Contains("duplicate id", StringComparison.Ordinal));
        errors.Should().Contain(error => error.Contains("unsupported provider", StringComparison.Ordinal));
        errors.Should().Contain(error => error.Contains("officialUrl", StringComparison.Ordinal));
        errors.Should().Contain(error => error.Contains("contentStatus", StringComparison.Ordinal));
    }
}
