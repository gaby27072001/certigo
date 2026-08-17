using FluentAssertions;
using Certigo.Application.Services;
using Certigo.Domain.Progress;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class PathServiceTests
{
    private const string UserId = "user-1";
    private static readonly DateTimeOffset Now = new(2025, 1, 6, 12, 0, 0, TimeSpan.Zero);

    private static PathService Build(InMemoryProgressRepository progress)
    {
        var content = TestContent.Build();
        var context = new FakeUserContext(UserId, "Tester");
        return new PathService(context, content, progress, new FakeClock(Now));
    }

    [Fact]
    public async Task GetPathAsync_with_no_progress_unlocks_only_first_lesson()
    {
        var progress = new InMemoryProgressRepository();
        var service = Build(progress);

        var path = await service.GetPathAsync(TestContent.TrackId);

        path.TrackName.Should().Be("Microsoft Azure Fundamentals");
        path.Exam.Should().Be("AZ-900");
        path.ReadinessScore.Should().Be(0);
        path.Units.Should().HaveCount(2);

        var unit1 = path.Units[0];
        unit1.Lessons[0].Status.Should().Be("available");
        unit1.Lessons[1].Status.Should().Be("locked");

        var unit2 = path.Units[1];
        unit2.Status.Should().Be("locked");
        unit2.Lessons.Should().OnlyContain(l => l.Status == "locked");
    }

    [Fact]
    public async Task GetPathAsync_completing_first_unit_unlocks_next_and_scores_domain()
    {
        var progress = new InMemoryProgressRepository();
        progress.Seed(UserId, Mastered("c1"));
        progress.Seed(UserId, Mastered("c2"));
        var service = Build(progress);

        var path = await service.GetPathAsync(TestContent.TrackId);

        var unit1 = path.Units[0];
        unit1.Lessons.Should().OnlyContain(l => l.Status == "mastered");
        unit1.Lessons[0].MasteryPct.Should().BeGreaterThan(80);

        var unit2 = path.Units[1];
        unit2.Status.Should().Be("available");
        unit2.Lessons[0].Status.Should().Be("available");

        path.ReadinessScore.Should().BeGreaterThan(0);
        path.Domains.Should().Contain(d => d.Id == "d-concepts" && d.Score > 0);
        path.Domains.Should().Contain(d => d.Id == "d-governance" && d.Score == 0);
    }

    private static ConceptMastery Mastered(string conceptId)
        => ConceptMastery.New(UserId, TestContent.TrackId, conceptId) with
        {
            MasteryScore = 0.9,
            Stability = 60,
            LastReviewedAt = Now,
            DueAt = Now.AddDays(30)
        };
}
