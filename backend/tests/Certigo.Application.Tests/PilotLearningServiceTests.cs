using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class PilotLearningServiceTests
{
    private const string PilotId = "responsible-ai-assistants";
    private static readonly string Digest = "sha256:" + new string('a', 64);

    [Fact]
    public async Task Lesson_access_and_read_declaration_are_owner_and_version_scoped()
    {
        var history = new InMemoryPilotHistoryRepository();
        var catalog = new FakePilotContentCatalog(Digest);
        var clock = new FakeClock(DateTimeOffset.Parse("2026-10-19T10:00:00Z"));
        var ownerA = CreateService("owner-A", clock, catalog, history);

        var opened = await ownerA.RecordAccessAsync(
            PilotId, "verify-claims", Digest, markRead: false);

        opened.Should().NotBeNull();
        opened!.MarkedReadAt.Should().BeNull();
        history.Records.Should().ContainSingle().Which.UserId.Should().Be("owner-A");

        clock.UtcNow = clock.UtcNow.AddMinutes(1);
        var marked = await ownerA.RecordAccessAsync(
            PilotId, "verify-claims", Digest, markRead: true);
        marked!.MarkedReadAt.Should().Be(clock.UtcNow);

        clock.UtcNow = clock.UtcNow.AddMinutes(1);
        var repeatedMark = await ownerA.RecordAccessAsync(
            PilotId, "verify-claims", Digest, markRead: true);
        repeatedMark!.MarkedReadAt.Should().Be(marked.MarkedReadAt);
        history.Records.Should().ContainSingle();

        var ownerB = CreateService("owner-B", clock, catalog, history);
        var otherOwnerHistory = await ownerB.GetHistoryAsync(PilotId, Digest);
        otherOwnerHistory.Should().NotBeNull();
        otherOwnerHistory!.Lessons.Should().BeEmpty();

        var ownerAHistory = await ownerA.GetHistoryAsync(PilotId, Digest);
        ownerAHistory!.LastLessonId.Should().Be("verify-claims");
        ownerAHistory.Lessons.Should().ContainSingle()
            .Which.MarkedReadAt.Should().Be(marked.MarkedReadAt);
    }

    [Fact]
    public async Task Stale_version_and_unknown_lesson_never_write_history()
    {
        var history = new InMemoryPilotHistoryRepository();
        var catalog = new FakePilotContentCatalog(Digest);
        var service = CreateService("owner-A", new FakeClock(DateTimeOffset.UtcNow), catalog, history);

        var stale = await service.RecordAccessAsync(
            PilotId, "verify-claims", "sha256:" + new string('b', 64), markRead: true);
        var unknown = await service.RecordAccessAsync(
            PilotId, "invented-lesson", Digest, markRead: true);
        var malformed = await service.GetHistoryAsync(PilotId, "not-a-digest");

        stale.Should().BeNull();
        unknown.Should().BeNull();
        malformed.Should().BeNull();
        history.Records.Should().BeEmpty();
    }

    [Fact]
    public async Task A_new_digest_starts_unread_without_rewriting_the_previous_version()
    {
        var history = new InMemoryPilotHistoryRepository();
        var catalog = new FakePilotContentCatalog(Digest);
        var service = CreateService("owner-A", new FakeClock(DateTimeOffset.UtcNow), catalog, history);
        await service.RecordAccessAsync(PilotId, "verify-claims", Digest, markRead: true);

        var nextDigest = "sha256:" + new string('b', 64);
        catalog.ContentDigest = nextDigest;

        var nextVersion = await service.GetHistoryAsync(PilotId, nextDigest);

        nextVersion.Should().NotBeNull();
        nextVersion!.Lessons.Should().BeEmpty();
        history.Records.Should().ContainSingle().Which.ContentDigest.Should().Be(Digest);
    }

    private static PilotLearningService CreateService(
        string userId,
        FakeClock clock,
        FakePilotContentCatalog catalog,
        InMemoryPilotHistoryRepository history) =>
        new(new FakeUserContext(userId), clock, catalog, history);

    private sealed class FakeUserContext(string userId) : IUserContext
    {
        public string UserId => userId;
        public string DisplayName => "Synthetic learner";
    }

    private sealed class FakeClock(DateTimeOffset utcNow) : IClock
    {
        public DateTimeOffset UtcNow { get; set; } = utcNow;
    }

    private sealed class FakePilotContentCatalog(string contentDigest) : IPilotContentCatalog
    {
        public string ContentDigest { get; set; } = contentDigest;

        public Task<PilotContentPackage?> GetAsync(
            string pilotId,
            CancellationToken cancellationToken = default)
        {
            PilotContentPackage? package = pilotId != PilotId
                ? null
                : new PilotContentPackage(
                    PilotId,
                    ContentDigest,
                    [],
                    new HashSet<string>(StringComparer.Ordinal)
                    {
                        "verify-claims",
                        "retrieval-not-training",
                        "stop-and-escalate",
                    });
            return Task.FromResult(package);
        }
    }

    private sealed class InMemoryPilotHistoryRepository : IPilotHistoryRepository
    {
        public List<PilotLessonHistoryRecord> Records { get; } = [];

        public Task<IReadOnlyList<PilotLessonHistoryRecord>> ListAsync(
            string userId,
            string pilotId,
            string contentDigest,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<PilotLessonHistoryRecord>>(
                Records.Where(record => record.UserId == userId
                    && record.PilotId == pilotId
                    && record.ContentDigest == contentDigest).ToArray());

        public Task<PilotLessonHistoryRecord> RecordAsync(
            PilotLessonHistoryRecord activity,
            bool markRead,
            CancellationToken cancellationToken = default)
        {
            var index = Records.FindIndex(record => record.Id == activity.Id);
            if (index >= 0)
            {
                var existing = Records[index];
                activity = activity with
                {
                    LastAccessedAt = existing.LastAccessedAt >= activity.LastAccessedAt
                        ? existing.LastAccessedAt
                        : activity.LastAccessedAt,
                    MarkedReadAt = existing.MarkedReadAt
                        ?? (markRead ? activity.LastAccessedAt : null),
                };
                Records[index] = activity;
            }
            else
            {
                Records.Add(activity);
            }

            return Task.FromResult(activity);
        }
    }
}
