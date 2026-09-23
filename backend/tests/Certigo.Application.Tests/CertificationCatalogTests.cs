using System.Text.Json.Nodes;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class CertificationCatalogTests
{
    // Derived from certigo-content PR #20 head 2f0d1d9cd2d1982d615b14497310bd396b9fa7fd.
    // Upstream certifications.json blob SHA: cd8bf014d6ff997e496ec8cc042de4b7d82d85f3.
    [Fact]
    public void Parser_accepts_the_exact_canonical_v1_contract_fixture()
    {
        var document = ParseFixture();

        document.Schema.Should().Be(CertificationCatalogSchemas.SourceV1);
        document.AsOf.Should().Be(new DateOnly(2026, 8, 17));
        document.Freshness.Should().Be(new CertificationCatalogFreshness(30, new DateOnly(2026, 9, 16)));
        document.Providers.Should().BeEquivalentTo(
        [
            new CertificationProviderDefinition(
                "aws",
                "Amazon Web Services",
                "aws",
                "https://docs.aws.amazon.com/aws-certification/latest/examguides/aws-certification-exam-guides.html",
                ["aws.amazon.com", "d1.awsstatic.com", "docs.aws.amazon.com"],
                new DateOnly(2026, 8, 17)),
            new CertificationProviderDefinition(
                "gcp",
                "Google Cloud",
                "gcp",
                "https://cloud.google.com/learn/certification",
                ["cloud.google.com", "services.google.com", "support.google.com"],
                new DateOnly(2026, 8, 17)),
            new CertificationProviderDefinition(
                "microsoft",
                "Microsoft",
                "microsoft",
                null,
                ["learn.microsoft.com"],
                null),
        ], options => options.WithStrictOrdering());

        document.Certifications.Select(entry => entry.Id).Should().Equal(
            "aws:ans-c01",
            "aws:dva-c02",
            "gcp:cloud-digital-leader");
        document.Certifications.Should().NotContain(entry => entry.Id == "aws:dva-c03");

        var dva = document.Certifications.Single(entry => entry.Id == "aws:dva-c02");
        dva.Status.Should().Be("active");
        dva.Guide.Url.Should().Be(
            "https://docs.aws.amazon.com/aws-certification/latest/developer-associate-02/developer-associate-02.html");
        dva.Lifecycle!.Successor.Should().Be("aws:dva-c03");
        dva.Lifecycle.LastExamOn.Should().Be(new DateOnly(2026, 11, 30));

        var gcp = document.Certifications.Single(entry => entry.Id == "gcp:cloud-digital-leader");
        gcp.OfficialCode.Should().BeNull();
        gcp.Blueprint.Objectives.Should().OnlyContain(objective => objective.WeightType == "approximate");
    }

    [Fact]
    public void Parser_preserves_decimal_objective_weights_without_truncation()
    {
        var json = ReadFixture().Replace(
            "\"weightPercent\": 18,",
            "\"weightPercent\": 18.5,",
            StringComparison.Ordinal);

        var document = new CertificationCatalogParser().Parse(json);

        document.Certifications.Single(entry => entry.Id == "gcp:cloud-digital-leader")
            .Blueprint.Objectives.First().WeightPercent.Should().Be(18.5m);
    }

    [Fact]
    public void Parser_rejects_unknown_source_schema()
    {
        var json = ReadFixture().Replace(
            CertificationCatalogSchemas.SourceV1,
            "certigo.certification-catalog/v2",
            StringComparison.Ordinal);

        var act = () => new CertificationCatalogParser().Parse(json);

        act.Should().Throw<InvalidDataException>()
            .WithMessage("*schema must be 'certigo.certification-catalog/v1'*");
    }

    // certigo-content PR #84 (2026-09-08) added the optional lifecycle.transition
    // field to the canonical catalog; releases carrying it must stay importable.
    [Theory]
    [InlineData("announced")]
    [InlineData("none-announced")]
    public void Parser_accepts_each_canonical_lifecycle_transition(string transition)
    {
        var document = new CertificationCatalogParser().Parse(WithDvaTransition(transition));

        document.Certifications.Single(entry => entry.Id == "aws:dva-c02")
            .Lifecycle!.Transition.Should().Be(transition);
    }

    [Fact]
    public void Parser_keeps_lifecycles_without_transition_valid()
    {
        var document = ParseFixture();

        document.Certifications.Where(entry => entry.Lifecycle is not null)
            .Should().OnlyContain(entry => entry.Lifecycle!.Transition == null);
    }

    [Fact]
    public void Parser_rejects_a_lifecycle_transition_outside_the_canonical_enum()
    {
        var act = () => new CertificationCatalogParser().Parse(WithDvaTransition("scheduled"));

        act.Should().Throw<InvalidDataException>()
            .WithMessage("*aws:dva-c02: lifecycle.transition is unsupported.*");
    }

    private static string WithDvaTransition(string transition)
    {
        var catalog = JsonNode.Parse(ReadFixture())!.AsObject();
        var dva = catalog["certifications"]!.AsArray()
            .Single(entry => (string?)entry!["id"] == "aws:dva-c02")!;
        dva["lifecycle"]!["transition"] = transition;
        return catalog.ToJsonString();
    }

    private static CertificationCatalogDocument ParseFixture()
        => new CertificationCatalogParser().Parse(ReadFixture());

    private static string ReadFixture()
    {
        var assembly = typeof(CertificationCatalogTests).Assembly;
        var resourceName = assembly.GetManifestResourceNames()
            .Single(name => name.EndsWith("canonical-certification-catalog-v1.json", StringComparison.Ordinal));
        using var stream = assembly.GetManifestResourceStream(resourceName)!;
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}
