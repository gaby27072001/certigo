using System.Text.Json;
using System.Text.Json.Nodes;
using Certigo.Application.Abstractions;
using Certigo.Infrastructure.ContentContracts;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class EmbeddedCertificationCatalogSchemaTests
{
    private const string SchemaFileName = "certification-catalog.schema.json";

    private readonly JsonSchemaContentContractValidator _validator = new();

    [Fact]
    public void Embedded_schema_accepts_a_lifecycle_without_transition()
    {
        var act = () => _validator.Validate(SchemaFileName, ToElement(ReadFixture()));

        act.Should().NotThrow();
    }

    // certigo-content PR #84 (2026-09-08) added the optional lifecycle.transition
    // field; without it in the embedded schema every newer release is rejected.
    [Theory]
    [InlineData("announced")]
    [InlineData("none-announced")]
    public void Embedded_schema_accepts_each_canonical_lifecycle_transition(string transition)
    {
        var catalog = ReadFixture();
        DvaLifecycle(catalog)["transition"] = transition;

        var act = () => _validator.Validate(SchemaFileName, ToElement(catalog));

        act.Should().NotThrow();
    }

    [Fact]
    public void Embedded_schema_rejects_a_lifecycle_transition_outside_the_canonical_enum()
    {
        var catalog = ReadFixture();
        DvaLifecycle(catalog)["transition"] = "scheduled";

        var act = () => _validator.Validate(SchemaFileName, ToElement(catalog));

        act.Should().Throw<ContentReleaseValidationException>();
    }

    [Fact]
    public void Embedded_schema_still_rejects_undeclared_lifecycle_properties()
    {
        var catalog = ReadFixture();
        DvaLifecycle(catalog)["transitionOn"] = "2026-12-01";

        var act = () => _validator.Validate(SchemaFileName, ToElement(catalog));

        act.Should().Throw<ContentReleaseValidationException>();
    }

    private static JsonObject DvaLifecycle(JsonObject catalog)
        => catalog["certifications"]!.AsArray()
            .Single(entry => (string?)entry!["id"] == "aws:dva-c02")!["lifecycle"]!.AsObject();

    private static JsonElement ToElement(JsonObject catalog)
    {
        using var document = JsonDocument.Parse(catalog.ToJsonString());
        return document.RootElement.Clone();
    }

    private static JsonObject ReadFixture()
    {
        var assembly = typeof(EmbeddedCertificationCatalogSchemaTests).Assembly;
        using var stream = assembly.GetManifestResourceStream(
            "Certigo.Infrastructure.Tests.Fixtures.canonical-certification-catalog-v1.json")!;
        return JsonNode.Parse(stream)!.AsObject();
    }
}
