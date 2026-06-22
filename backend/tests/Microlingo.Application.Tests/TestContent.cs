using Microlingo.Application.Dtos;
using Microlingo.Application.Services;
using Microlingo.Domain.Content;

namespace Microlingo.Application.Tests;

/// Builds a small but self-consistent AZ-900-shaped track (2 units, 3 lessons,
/// 3 concepts across 2 weighted domains) plus matching public lessons and
/// server-side answer keys, so the application services can be exercised exactly
/// as they would be against Cosmos.
internal static class TestContent
{
    public const string TrackId = "az-900";

    public static InMemoryContentRepository Build()
    {
        var repo = new InMemoryContentRepository();

        repo.AddTrack(new Track(
            Id: TrackId,
            Code: "AZ-900",
            Title: "Azure Fundamentals",
            Summary: "Foundations of Azure.",
            Domains: new[]
            {
                new ExamDomain("d-concepts", "Cloud concepts", 0.5),
                new ExamDomain("d-governance", "Governance", 0.5)
            },
            Units: new[]
            {
                new TrackUnit("u1", "d-concepts", "Cloud concepts", new[] { "l1", "l2" }),
                new TrackUnit("u2", "d-governance", "Governance", new[] { "l3" })
            }));

        AddLesson(repo, "l1", "u1", "d-concepts", "CapEx vs OpEx", "c1");
        AddLesson(repo, "l2", "u1", "d-concepts", "Shared responsibility", "c2");
        AddLesson(repo, "l3", "u2", "d-governance", "Azure Policy", "c3");

        return repo;
    }

    private static void AddLesson(InMemoryContentRepository repo, string lessonId, string unitId, string domainId, string title, string conceptId)
    {
        var check = new LessonCheck(
            Id: $"{lessonId}-i1",
            ConceptId: conceptId,
            Type: ItemType.Mcq,
            Stem: $"{title}?",
            Options: new[] { new CheckOption("a", "Correct"), new CheckOption("b", "Wrong") });

        repo.AddLesson(new Lesson(
            Id: lessonId,
            TrackId: TrackId,
            UnitId: unitId,
            DomainId: domainId,
            Title: title,
            EstMinutes: 4,
            Blocks: new[]
            {
                new LessonBlock("concept", conceptId, Title: title, Body: "Body."),
                new LessonBlock("check", conceptId, Check: check)
            }));

        repo.AddAnswerKey(new LessonAnswerKey(
            LessonId: lessonId,
            TrackId: TrackId,
            DomainId: domainId,
            Items: new[]
            {
                new AnswerKeyItem($"{lessonId}-i1", conceptId, ItemType.Mcq, 1, new[] { "a" }, "Because a is correct.")
            }));
    }

    public static UserProfileDto NewProfile(string userId, int dailyGoalXp = 50)
        => new(
            Id: userId,
            DisplayName: "Tester",
            Handle: "tester",
            AvatarUrl: null,
            Xp: 0,
            Level: 1,
            StreakDays: 0,
            FreezeTokens: 2,
            DailyGoalXp: dailyGoalXp,
            DailyXpEarned: 0,
            Gems: 0,
            ActiveTrackId: TrackId,
            LastActiveDate: null,
            DailyXpDate: null);
}
