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

    // The four item types the runtime v4 contract can publish (#245): each keeps
    // its answers in the server-only key and ships an answer-free public check.
    [Theory]
    [InlineData(ItemType.Mcq, new[] { "paas" })]
    [InlineData(ItemType.Multi, new[] { "iaas", "paas" })]
    [InlineData(ItemType.Scenario, new[] { "paas" })]
    [InlineData(ItemType.SpotTheIssue, new[] { "iaas" })]
    public void Every_publishable_type_separates_answers_from_the_public_check(
        ItemType itemType,
        string[] correct)
    {
        var graph = BuildGraph(questionBank: false, itemType, correct);

        var projection = new RuntimeContentProjector().Project(graph);

        var check = projection.Lessons.Should().ContainSingle().Subject.Lesson.Blocks[1].Check!;
        check.Type.Should().Be(itemType);
        var publicJson = System.Text.Json.JsonSerializer.Serialize(
            projection.Lessons[0].Lesson,
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));
        foreach (var forbidden in new[] { "correct", "explanation", "rationale", "answerKey", "solution", "pairs" })
        {
            publicJson.Should().NotContain($"\"{forbidden}\"", $"the public {itemType} check must not leak {forbidden}");
        }

        publicJson.Should().NotContain("PaaS is managed.");
        var key = projection.AnswerKeys.Should().ContainSingle().Subject.AnswerKey.Items.Should().ContainSingle().Subject;
        key.Type.Should().Be(itemType);
        key.Correct.Should().Equal(correct);
        key.Explanation.Should().Be("PaaS is managed.");
    }


    [Fact]
    public void Match_pairs_projection_transports_public_matches_without_null_matches()
    {
        var matches = new[]
        {
            new CheckOption("r-all", "All resources"),
            new CheckOption("r-resources", "Create and manage resources"),
        };
        var graph = BuildGraph(
            questionBank: false,
            ItemType.MatchPairs,
            ["l-owner:r-all", "l-contributor:r-resources"],
            [new CheckOption("l-owner", "Owner"), new CheckOption("l-contributor", "Contributor")],
            matches);

        var projection = new RuntimeContentProjector().Project(graph);

        var check = projection.Lessons.Should().ContainSingle().Subject.Lesson.Blocks[1].Check!;
        check.Matches.Should().Equal(matches);
        projection.AnswerKeys.Should().ContainSingle().Subject.AnswerKey.Items.Should().ContainSingle()
            .Subject.Correct.Should().Equal("l-owner:r-all", "l-contributor:r-resources");

        var publicJson = System.Text.Json.JsonSerializer.Serialize(
            projection.Lessons[0].Lesson,
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));
        publicJson.Should().Contain("\"matches\"");

        var graphWithoutMatches = BuildGraph(questionBank: false);
        var withoutMatches = new RuntimeContentProjector().Project(graphWithoutMatches);
        var legacyJson = System.Text.Json.JsonSerializer.Serialize(
            withoutMatches.Lessons[0].Lesson,
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));
        legacyJson.Should().NotContain("\"matches\"");
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
    public void Guided_content_only_lesson_is_rejected()
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

        var action = () => new RuntimeContentProjector().Project(graph);

        action.Should().Throw<ContentProjectionException>()
            .WithMessage($"*Guided lesson '{lesson.Id}' must contain at least one check*");
    }

    [Fact]
    public void Retired_track_is_excluded_from_the_active_projection()
    {
        var graph = BuildGraph(questionBank: false);
        var track = graph.Tracks.Values.Single();
        graph = graph with
        {
            Tracks = new Dictionary<string, CanonicalTrackResource>(StringComparer.Ordinal)
            {
                [track.Id] = track with
                {
                    Lifecycle = new CanonicalContentLifecycle(
                        "retired",
                        new DateOnly(2026, 6, 30)),
                },
            },
        };

        var projection = new RuntimeContentProjector().Project(graph);

        projection.Tracks.Should().BeEmpty();
        projection.Lessons.Should().BeEmpty();
        projection.AnswerKeys.Should().BeEmpty();
    }

    [Fact]
    public void Planned_track_and_its_children_are_excluded_from_the_active_projection()
    {
        var graph = BuildGraph(questionBank: false);
        var track = graph.Tracks.Values.Single();
        graph = graph with
        {
            Tracks = new Dictionary<string, CanonicalTrackResource>(StringComparer.Ordinal)
            {
                [track.Id] = track with
                {
                    Lifecycle = new CanonicalContentLifecycle("planned"),
                },
            },
        };

        var projection = new RuntimeContentProjector().Project(graph);

        projection.Tracks.Should().BeEmpty();
        projection.Lessons.Should().BeEmpty();
        projection.AnswerKeys.Should().BeEmpty();
    }

    [Fact]
    public void Track_past_its_recommendation_window_is_excluded()
    {
        var graph = BuildGraph(questionBank: true);
        var certification = graph.Certifications.Values.Single();
        graph = graph with
        {
            Certifications = new Dictionary<string, CanonicalCertification>(StringComparer.Ordinal)
            {
                [certification.Id] = certification with
                {
                    Status = "active-retiring",
                    LastExamOn = new DateOnly(2026, 12, 31),
                    RecommendThrough = new DateOnly(2026, 8, 30),
                },
            },
            AsOf = new DateOnly(2026, 8, 31),
        };

        var projection = new RuntimeContentProjector().Project(graph);

        projection.Tracks.Should().BeEmpty();
        projection.Lessons.Should().BeEmpty();
        projection.AnswerKeys.Should().BeEmpty();
    }

    private static CanonicalContentGraph BuildGraph(
        bool questionBank,
        ItemType itemType = ItemType.Mcq,
        IReadOnlyList<string>? correct = null,
        IReadOnlyList<CheckOption>? options = null,
        IReadOnlyList<CheckOption>? matches = null)
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
        var lifecycle = new CanonicalContentLifecycle("active");
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
            itemType,
            2,
            "Which service model?",
            options ?? [new CheckOption("iaas", "IaaS"), new CheckOption("paas", "PaaS")],
            matches);
        var solution = new CanonicalSolution(questionId, correct ?? ["paas"], "PaaS is managed.");
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
                    "active",
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
