using FluentAssertions;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Services;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Tutor;
using Xunit;

namespace Microlingo.Application.Tests;

public sealed class RecommendationServiceTests
{
    private const string UserId = "user-1";
    private static readonly DateTimeOffset Now = new(2025, 6, 1, 12, 0, 0, TimeSpan.Zero);

    private static RecommendationService Build(
        InMemoryProgressRepository progress,
        InMemoryLearnerModelRepository learnerModels)
    {
        var content = TestContent.Build();
        var context = new FakeUserContext(UserId, "Tester");
        return new RecommendationService(context, content, progress, learnerModels, new FakeClock(Now));
    }

    [Fact]
    public async Task GetNextBestAsync_for_fresh_user_recommends_starting_the_first_lesson()
    {
        var service = Build(new InMemoryProgressRepository(), new InMemoryLearnerModelRepository());

        var result = await service.GetNextBestAsync(TestContent.TrackId);

        result.TrackId.Should().Be(TestContent.TrackId);
        result.GeneratedAt.Should().Be(Now);
        result.Items.Should().NotBeEmpty();

        var top = result.Items[0];
        top.Kind.Should().Be("start");
        top.LessonId.Should().Be("l1");
        top.Title.Should().Be("CapEx vs OpEx");
        top.Reason.Should().Contain("Cloud concepts");
    }

    [Fact]
    public async Task GetNextBestAsync_with_overdue_mastery_recommends_review_first()
    {
        var progress = new InMemoryProgressRepository();
        // c1 was learned but is now well past due with a fragile memory.
        progress.Seed(UserId, ConceptMastery.New(UserId, TestContent.TrackId, "c1") with
        {
            MasteryScore = 0.7,
            Stability = 8,
            LastReviewedAt = Now.AddDays(-10),
            DueAt = Now.AddDays(-3)
        });
        var service = Build(progress, new InMemoryLearnerModelRepository());

        var result = await service.GetNextBestAsync(TestContent.TrackId);

        var top = result.Items[0];
        top.Kind.Should().Be("review");
        top.ConceptId.Should().Be("c1");
        top.ForgettingRiskPct.Should().BeGreaterThan(0);
        top.Reason.Should().Contain("Révision due");
    }

    [Fact]
    public async Task GetNextBestAsync_with_recurring_struggle_recommends_practice_first()
    {
        var learnerModels = new InMemoryLearnerModelRepository();
        await learnerModels.UpsertAsync(new LearnerModelRecord(
            UserId,
            TestContent.TrackId,
            new[]
            {
                new LearnerConceptStat(
                    "c1",
                    Attempts: 3,
                    Correct: 0,
                    Errors: 3,
                    ConsecutiveErrors: 3,
                    WrongOptionTally: new Dictionary<string, int> { ["b"] = 3 },
                    LastWrongOptionId: "b",
                    LastSeen: Now.AddDays(-1))
            },
            Now.AddDays(-1)));
        var service = Build(new InMemoryProgressRepository(), learnerModels);

        var result = await service.GetNextBestAsync(TestContent.TrackId);

        var top = result.Items[0];
        top.Kind.Should().Be("practice");
        top.ConceptId.Should().Be("c1");
        top.LessonId.Should().Be("l1");
        top.EstMinutes.Should().Be(4);
        top.Reason.Should().Contain("Tu butes");
    }

    [Fact]
    public async Task GetNextBestAsync_caps_the_number_of_items()
    {
        var service = Build(new InMemoryProgressRepository(), new InMemoryLearnerModelRepository());

        var result = await service.GetNextBestAsync(TestContent.TrackId);

        result.Items.Count.Should().BeLessThanOrEqualTo(5);
    }

    [Fact]
    public async Task GetNextBestAsync_for_unknown_track_returns_empty()
    {
        var service = Build(new InMemoryProgressRepository(), new InMemoryLearnerModelRepository());

        var result = await service.GetNextBestAsync("does-not-exist");

        result.TrackId.Should().Be("does-not-exist");
        result.Items.Should().BeEmpty();
    }
}
