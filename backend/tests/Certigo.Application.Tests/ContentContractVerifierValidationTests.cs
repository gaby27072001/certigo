using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class ContentContractVerifierValidationTests
{
    [Fact]
    public void Invalid_catalog_is_a_deterministic_release_validation_failure()
    {
        using var catalog = JsonDocument.Parse("""{"schema":"unsupported"}""");
        IReadOnlyDictionary<string, JsonElement> resources =
            new Dictionary<string, JsonElement>(StringComparer.Ordinal)
            {
                ["catalog/certifications.json"] = catalog.RootElement,
            };

        var action = () => ContentContractVerifier.ParseCatalog(resources);

        action.Should().Throw<ContentReleaseValidationException>()
            .WithMessage("Certification catalog is invalid.")
            .WithInnerException<InvalidDataException>();
    }

    [Fact]
    public void Guided_question_without_a_lesson_check_is_rejected()
    {
        const string certificationId = "microsoft:az-900";
        const string trackId = "microsoft.az-900.track.main";
        const string domainId = "microsoft.az-900.domain.section-1";
        const string unitId = "microsoft.az-900.unit.cloud";
        const string lessonId = "microsoft.az-900.lesson.cloud";
        const string conceptId = "microsoft.az-900.concept.cloud";
        const string questionId = "microsoft.az-900.section-1.cloud.001";
        var lifecycle = new CanonicalContentLifecycle("active");
        var graph = new CanonicalContentGraph(
            new Dictionary<string, CanonicalCertification>(StringComparer.Ordinal)
            {
                [certificationId] = new(
                    certificationId,
                    "az-900",
                    "AZ-900",
                    "Azure Fundamentals",
                    "foundational",
                    "active",
                    "2026-08-17",
                    [new CanonicalCertificationObjective("section-1", "Cloud concepts", 100m)]),
            },
            new Dictionary<string, CanonicalTrackResource>(StringComparer.Ordinal)
            {
                [trackId] = new(
                    trackId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "guided",
                    "Cloud foundations",
                    [domainId],
                    [unitId],
                    lifecycle),
            },
            new Dictionary<string, CanonicalDomainResource>(StringComparer.Ordinal)
            {
                [domainId] = new(
                    domainId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "section-1",
                    lifecycle),
            },
            new Dictionary<string, CanonicalUnitResource>(StringComparer.Ordinal)
            {
                [unitId] = new(
                    unitId,
                    null,
                    certificationId,
                    "2026-08-17",
                    domainId,
                    "Cloud",
                    [lessonId],
                    lifecycle),
            },
            new Dictionary<string, CanonicalLessonResource>(StringComparer.Ordinal)
            {
                [lessonId] = new(
                    lessonId,
                    null,
                    certificationId,
                    "2026-08-17",
                    unitId,
                    "Cloud",
                    2,
                    [
                        new CanonicalLessonBlock(
                            $"{lessonId}.block.001",
                            "concept",
                            conceptId,
                            Body: "Cloud concepts"),
                    ],
                    lifecycle),
            },
            new Dictionary<string, CanonicalConceptResource>(StringComparer.Ordinal)
            {
                [conceptId] = new(
                    conceptId,
                    null,
                    certificationId,
                    "2026-08-17",
                    domainId,
                    "Cloud",
                    lifecycle),
            },
            new Dictionary<string, CanonicalQuestion>(StringComparer.Ordinal)
            {
                [questionId] = new(
                    questionId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "section-1",
                    domainId,
                    conceptId,
                    ItemType.Mcq,
                    2,
                    "Which model?",
                    [new CheckOption("iaas", "IaaS"), new CheckOption("paas", "PaaS")]),
            },
            new Dictionary<string, CanonicalSolution>(StringComparer.Ordinal)
            {
                [questionId] = new(questionId, ["paas"], "PaaS is managed."),
            });

        var action = () => ContentContractVerifier.ValidateGraph(graph);

        action.Should().Throw<ContentReleaseValidationException>()
            .WithMessage($"*Guided track '{trackId}' has orphan questions*{questionId}*");
    }

    [Fact]
    public void Active_question_bank_rejects_non_distributable_concepts()
    {
        const string certificationId = "aws:clf-c02";
        const string trackId = "aws.clf-c02.track.main";
        const string domainId = "aws.clf-c02.domain.domain-1";
        const string conceptId = "aws.clf-c02.concept.cloud";
        const string questionId = "aws.clf-c02.domain-1.cloud.001";
        var active = new CanonicalContentLifecycle("active");
        var graph = new CanonicalContentGraph(
            new Dictionary<string, CanonicalCertification>(StringComparer.Ordinal)
            {
                [certificationId] = new(
                    certificationId,
                    "clf-c02",
                    "CLF-C02",
                    "Cloud Practitioner",
                    "foundational",
                    "active",
                    "2026-08-17",
                    [new CanonicalCertificationObjective("domain-1", "Cloud concepts", 100m)]),
            },
            new Dictionary<string, CanonicalTrackResource>(StringComparer.Ordinal)
            {
                [trackId] = new(
                    trackId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "questionBank",
                    "Cloud practice",
                    [domainId],
                    [],
                    active),
            },
            new Dictionary<string, CanonicalDomainResource>(StringComparer.Ordinal)
            {
                [domainId] = new(
                    domainId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "domain-1",
                    active),
            },
            new Dictionary<string, CanonicalUnitResource>(StringComparer.Ordinal),
            new Dictionary<string, CanonicalLessonResource>(StringComparer.Ordinal),
            new Dictionary<string, CanonicalConceptResource>(StringComparer.Ordinal)
            {
                [conceptId] = new(
                    conceptId,
                    null,
                    certificationId,
                    "2026-08-17",
                    domainId,
                    "Cloud",
                    new CanonicalContentLifecycle("planned")),
            },
            new Dictionary<string, CanonicalQuestion>(StringComparer.Ordinal)
            {
                [questionId] = new(
                    questionId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "domain-1",
                    domainId,
                    conceptId,
                    ItemType.Mcq,
                    2,
                    "Which model?",
                    [new CheckOption("iaas", "IaaS"), new CheckOption("paas", "PaaS")]),
            },
            new Dictionary<string, CanonicalSolution>(StringComparer.Ordinal)
            {
                [questionId] = new(questionId, ["paas"], "PaaS is managed."),
            });

        var action = () => ContentContractVerifier.ValidateGraph(graph);

        action.Should().Throw<ContentReleaseValidationException>()
            .WithMessage(
                $"*question-bank track '{trackId}'*non-distributable concept '{conceptId}'*");
    }

    [Fact]
    public void Active_question_bank_rejects_empty_domains()
    {
        const string certificationId = "aws:clf-c02";
        const string trackId = "aws.clf-c02.track.main";
        const string domainId = "aws.clf-c02.domain.domain-1";
        var active = new CanonicalContentLifecycle("active");
        var graph = new CanonicalContentGraph(
            new Dictionary<string, CanonicalCertification>(StringComparer.Ordinal)
            {
                [certificationId] = new(
                    certificationId,
                    "clf-c02",
                    "CLF-C02",
                    "Cloud Practitioner",
                    "foundational",
                    "active",
                    "2026-08-17",
                    [new CanonicalCertificationObjective("domain-1", "Cloud concepts", 100m)]),
            },
            new Dictionary<string, CanonicalTrackResource>(StringComparer.Ordinal)
            {
                [trackId] = new(
                    trackId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "questionBank",
                    "Cloud practice",
                    [domainId],
                    [],
                    active),
            },
            new Dictionary<string, CanonicalDomainResource>(StringComparer.Ordinal)
            {
                [domainId] = new(
                    domainId,
                    null,
                    certificationId,
                    "2026-08-17",
                    "domain-1",
                    active),
            },
            new Dictionary<string, CanonicalUnitResource>(StringComparer.Ordinal),
            new Dictionary<string, CanonicalLessonResource>(StringComparer.Ordinal),
            new Dictionary<string, CanonicalConceptResource>(StringComparer.Ordinal),
            new Dictionary<string, CanonicalQuestion>(StringComparer.Ordinal),
            new Dictionary<string, CanonicalSolution>(StringComparer.Ordinal));

        var action = () => ContentContractVerifier.ValidateGraph(graph);

        action.Should().Throw<ContentReleaseValidationException>()
            .WithMessage(
                $"*question-bank track '{trackId}' has no questions for domain '{domainId}'*");
    }
}
