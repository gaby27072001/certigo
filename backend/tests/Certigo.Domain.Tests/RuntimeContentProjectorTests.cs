using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class RuntimeContentProjectorTests
{
    [Fact]
    public void Guided_projection_preserves_legacy_ids_and_separates_answers()
    {
        var graph = BuildGraph(questionBank: false);

        var projection = new RuntimeContentProjector().Project(graph);

        projection.Tracks.Should().ContainSingle();
        projection.Tracks[0].Track.Id.Should().Be("az-900");
        projection.Tracks[0].Track.Units[0].Lessons.Should().Equal("az900-lesson");
        projection.Lessons.Should().ContainSingle();
        projection.Lessons[0].Lesson.Blocks[1].Check.Should().NotBeNull();
        projection.Lessons[0].Lesson.Blocks[1].Check!.Id.Should().Be("az900-check-1");
        projection.Lessons[0].Lesson.Blocks[1].Check!.Options.Select(option => option.Id)
            .Should().Equal("iaas", "paas");
        projection.AnswerKeys.Should().ContainSingle();
        projection.AnswerKeys[0].AnswerKey.Items[0].Correct.Should().Equal("paas");
        projection.AnswerKeys[0].AnswerKey.Items[0].Explanation.Should().Be("PaaS is managed.");
    }

    [Fact]
    public void Question_bank_projection_synthesizes_one_practice_lesson_per_domain_deterministically()
    {
        var graph = BuildGraph(questionBank: true);

        var first = new RuntimeContentProjector().Project(graph);
        var second = new RuntimeContentProjector().Project(graph);

        first.Should().BeEquivalentTo(second, options => options.WithStrictOrdering());
        var track = first.Tracks.Should().ContainSingle().Subject.Track;
        track.Units.Should().ContainSingle();
        track.Units[0].Id.Should().Be("aws.clf-c02.track.main.unit.domain-1");
        track.Units[0].Lessons.Should()
            .Equal("aws.clf-c02.track.main.lesson.domain-1.practice");
        var lesson = first.Lessons.Should().ContainSingle().Subject.Lesson;
        lesson.EstMinutes.Should().Be(2);
        lesson.Blocks.Should().ContainSingle();
        lesson.Blocks[0].Check!.Id.Should().Be("aws.clf-c02.domain-1.cloud-value.001");
    }

    [Fact]
    public void Guided_content_only_lesson_has_an_empty_server_answer_key()
    {
        var graph = BuildGraph(questionBank: false);
        var lesson = graph.Lessons.Values.Single();
        graph = graph with
        {
            Lessons = new Dictionary<string, CanonicalLessonResource>(StringComparer.Ordinal)
            {
                [lesson.Id] = lesson with
                {
                    Blocks =
                    [
                        new CanonicalLessonBlock(
                            $"{lesson.Id}.block.001",
                            "concept",
                            lesson.Blocks[0].ConceptId,
                            Body: "Instruction"),
                        new CanonicalLessonBlock(
                            $"{lesson.Id}.block.002",
                            "recap",
                            lesson.Blocks[0].ConceptId,
                            Body: "Recap"),
                    ],
                },
            },
        };

        var projection = new RuntimeContentProjector().Project(graph);

        projection.AnswerKeys.Should().ContainSingle();
        projection.AnswerKeys[0].AnswerKey.Items.Should().BeEmpty();
    }

    private static CanonicalContentGraph BuildGraph(bool questionBank)
    {
        var provider = questionBank ? "aws" : "microsoft";
        var certificationSlug = questionBank ? "clf-c02" : "az-900";
        var certificationId = $"{provider}:{certificationSlug}";
        var trackId = $"{provider}.{certificationSlug}.track.main";
        var domainId = $"{provider}.{certificationSlug}.domain.cloud-concepts";
        var conceptId = $"{provider}.{certificationSlug}.concept.cloud-value";
        var questionId = $"{provider}.{certificationSlug}.domain-1.cloud-value.001";
        var unitId = $"{provider}.{certificationSlug}.unit.cloud-concepts";
        var lessonId = $"{provider}.{certificationSlug}.lesson.cloud-value";
        var lifecycle = new CanonicalContentLifecycle(questionBank ? "planned" : "active");
        var track = new CanonicalTrackResource(
            trackId,
            questionBank ? null : "az-900",
            certificationId,
            "2026-08-17",
            questionBank ? "questionBank" : "guided",
            "Cloud foundations",
            [domainId],
            questionBank ? [] : [unitId],
            lifecycle);
        var domain = new CanonicalDomainResource(
            domainId,
            questionBank ? null : "d-cloud",
            certificationId,
            "2026-08-17",
            "domain-1",
            lifecycle);
        var concept = new CanonicalConceptResource(
            conceptId,
            questionBank ? null : "c-cloud",
            certificationId,
            "2026-08-17",
            domainId,
            "Cloud value",
            lifecycle);
        var question = new CanonicalQuestion(
            questionId,
            questionBank ? null : "az900-check-1",
            certificationId,
            "2026-08-17",
            "domain-1",
            domainId,
            conceptId,
            ItemType.Mcq,
            2,
            "Which service model?",
            [new CheckOption("iaas", "IaaS"), new CheckOption("paas", "PaaS")]);
        var solution = new CanonicalSolution(questionId, ["paas"], "PaaS is managed.");
        var units = new Dictionary<string, CanonicalUnitResource>(StringComparer.Ordinal);
        var lessons = new Dictionary<string, CanonicalLessonResource>(StringComparer.Ordinal);
        if (!questionBank)
        {
            units.Add(unitId, new CanonicalUnitResource(
                unitId,
                "u-cloud",
                certificationId,
                "2026-08-17",
                domainId,
                "Cloud concepts",
                [lessonId],
                lifecycle));
            lessons.Add(lessonId, new CanonicalLessonResource(
                lessonId,
                "az900-lesson",
                certificationId,
                "2026-08-17",
                unitId,
                "Cloud value",
                5,
                [
                    new CanonicalLessonBlock(
                        $"{lessonId}.block.001",
                        "concept",
                        conceptId,
                        Body: "Concept body"),
                    new CanonicalLessonBlock(
                        $"{lessonId}.block.002",
                        "check",
                        conceptId,
                        QuestionId: questionId),
                ],
                lifecycle));
        }

        return new CanonicalContentGraph(
            new Dictionary<string, CanonicalCertification>(StringComparer.Ordinal)
            {
                [certificationId] = new CanonicalCertification(
                    certificationId,
                    certificationSlug,
                    questionBank ? "CLF-C02" : "AZ-900",
                    "Cloud certification",
                    "foundational",
                    questionBank ? "announced" : "active",
                    "2026-08-17",
                    [new CanonicalCertificationObjective("domain-1", "Cloud concepts", 100m)]),
            },
            new Dictionary<string, CanonicalTrackResource>(StringComparer.Ordinal) { [trackId] = track },
            new Dictionary<string, CanonicalDomainResource>(StringComparer.Ordinal) { [domainId] = domain },
            units,
            lessons,
            new Dictionary<string, CanonicalConceptResource>(StringComparer.Ordinal) { [conceptId] = concept },
            new Dictionary<string, CanonicalQuestion>(StringComparer.Ordinal) { [questionId] = question },
            new Dictionary<string, CanonicalSolution>(StringComparer.Ordinal) { [questionId] = solution });
    }
}
