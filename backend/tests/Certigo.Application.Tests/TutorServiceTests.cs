using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class TutorServiceHarness
{
    public InMemoryContentRepository Content { get; } = TestContent.Build();
    public InMemoryLearnerModelRepository LearnerModels { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public SpyTutorLlmTelemetry Telemetry { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public TutorService Build(string? completionReply = null)
    {
        var context = new FakeUserContext(UserId, "Tester");
        return new TutorService(context, Clock, Content, LearnerModels, new FakeTutorCompletion(completionReply), Telemetry, Events);
    }

    public TutorService Build(ITutorCompletion completion)
    {
        var context = new FakeUserContext(UserId, "Tester");
        return new TutorService(context, Clock, Content, LearnerModels, completion, Telemetry, Events);
    }

    public static TutorExplainRequest Request(params string[] selected)
        => new(TestContent.TrackId, "l1", "l1-i1", selected.ToList());
}

public sealed class TutorServiceTests
{
    [Fact]
    public async Task ExplainAsync_correct_answer_serves_grounded_explanation()
    {
        var h = new TutorServiceHarness();
        var service = h.Build();

        var dto = await service.ExplainAsync(TutorServiceHarness.Request("a"));

        dto.Correct.Should().BeTrue();
        dto.Source.Should().Be("grounded");
        dto.ItemId.Should().Be("l1-i1");
        dto.ConceptId.Should().Be("c1");
        dto.CitedConceptIds.Should().Contain("c1");
        dto.Recommendation.Should().NotBeNullOrWhiteSpace();
        dto.Personalization.Attempts.Should().Be(0); // history is read BEFORE this answer
    }

    [Fact]
    public async Task ExplainAsync_incorrect_answer_flags_result_and_persists_learning()
    {
        var h = new TutorServiceHarness();
        var service = h.Build();

        var dto = await service.ExplainAsync(TutorServiceHarness.Request("b"));

        dto.Correct.Should().BeFalse();
        dto.Recommendation.Should().Contain("retry this concept");

        var record = await h.LearnerModels.GetAsync(h.UserId, TestContent.TrackId);
        record.Should().NotBeNull();
        var stat = record!.Concepts.Single(c => c.ConceptId == "c1");
        stat.Attempts.Should().Be(1);
        stat.Errors.Should().Be(1);
        stat.WrongOptionTally["b"].Should().Be(1);
    }

    [Fact]
    public async Task ExplainAsync_emits_tutor_explained_event()
    {
        var h = new TutorServiceHarness();
        var service = h.Build();

        await service.ExplainAsync(TutorServiceHarness.Request("a"));

        h.Events.Events.Should().ContainSingle(e => e.Type == "tutor.explained");
    }

    [Fact]
    public async Task ExplainAsync_adopts_guardrail_passing_llm_reply()
    {
        var reply = """
        Sure! Here is the explanation:
        {
          "headline": "Spot on — OpEx is consumption-based.",
          "points": ["You pay only for what you use with OpEx."],
          "encouragement": "Great instincts here.",
          "citedConceptIds": ["c1"]
        }
        """;
        var h = new TutorServiceHarness();
        var service = h.Build(reply);

        var dto = await service.ExplainAsync(TutorServiceHarness.Request("a"));

        dto.Source.Should().Be("ai");
        dto.Headline.Should().Be("Spot on — OpEx is consumption-based.");
        h.Telemetry.SuccessCalls.Should().ContainSingle();
        h.Telemetry.SuccessCalls[0].Should().BePositive();
        // Recommendation always stays grounded, never taken from the model.
        dto.Recommendation.Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public async Task ExplainAsync_falls_back_to_grounded_when_llm_hallucinates_a_concept()
    {
        var reply = """
        {
          "headline": "Here is a made-up grounding.",
          "points": ["Trust me on this."],
          "encouragement": "Onward!",
          "citedConceptIds": ["c-not-real"]
        }
        """;
        var h = new TutorServiceHarness();
        var service = h.Build(reply);

        var dto = await service.ExplainAsync(TutorServiceHarness.Request("a"));

        dto.Source.Should().Be("grounded");
        dto.Headline.Should().NotBe("Here is a made-up grounding.");
        h.Telemetry.RejectedResponses.Should().ContainSingle(x => x.Reason == "guardrail_rejected");
    }

    [Fact]
    public async Task ExplainAsync_falls_back_to_grounded_when_llm_provider_is_temporarily_unavailable()
    {
        var h = new TutorServiceHarness();
        var service = h.Build(new ThrowingTutorCompletion(
            new TutorCompletionUnavailableException("azure openai unavailable")));

        var dto = await service.ExplainAsync(TutorServiceHarness.Request("a"));

        dto.Source.Should().Be("grounded");
        h.Telemetry.ControlledFallbacks.Should().ContainSingle(x => x.Reason == "provider_unavailable");
    }

    [Fact]
    public async Task ExplainAsync_surfaces_unexpected_llm_failures()
    {
        var h = new TutorServiceHarness();
        var service = h.Build(new ThrowingTutorCompletion(new InvalidOperationException("bug")));

        var act = async () => await service.ExplainAsync(TutorServiceHarness.Request("a"));

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("bug");
        h.Telemetry.UnexpectedErrors.Should().ContainSingle(x => x.ExceptionType == nameof(InvalidOperationException));
    }

    [Fact]
    public async Task ExplainAsync_personalises_after_repeated_struggles()
    {
        var h = new TutorServiceHarness();
        var service = h.Build();

        // Miss the same item, picking the same wrong option, three times.
        await service.ExplainAsync(TutorServiceHarness.Request("b"));
        await service.ExplainAsync(TutorServiceHarness.Request("b"));
        var third = await service.ExplainAsync(TutorServiceHarness.Request("b"));

        // By the third consult, history (before this answer) shows a recurring
        // struggle and the learner's signature wrong option, resolved to a label.
        third.Personalization.Attempts.Should().Be(2);
        third.Personalization.Errors.Should().Be(2);
        third.Personalization.RecurringStruggle.Should().BeTrue();
        third.Personalization.TopConfusedOption.Should().Be("Wrong");
        third.Headline.Should().Be("This one keeps tripping you up — let's lock it in.");
    }

    [Fact]
    public async Task ExplainAsync_records_a_comeback_as_improving()
    {
        var h = new TutorServiceHarness();
        var service = h.Build();

        // Two misses build a recurring struggle, then a correct answer.
        await service.ExplainAsync(TutorServiceHarness.Request("b"));
        await service.ExplainAsync(TutorServiceHarness.Request("b"));
        var comeback = await service.ExplainAsync(TutorServiceHarness.Request("a"));

        comeback.Correct.Should().BeTrue();
        comeback.Personalization.Trend.Should().Be("improving");
        comeback.Headline.Should().Be("Big improvement — you turned this one around!");
    }
}
