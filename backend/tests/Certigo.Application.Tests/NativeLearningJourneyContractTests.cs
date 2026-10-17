using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class NativeLearningJourneyContractTests
{
    [Theory]
    [InlineData("a", true)]
    [InlineData("b", false)]
    public async Task Existing_services_discover_grade_and_resume_progress_without_recrediting(
        string selectedOption,
        bool correct)
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId) with { ActiveTrackId = null });
        var owner = new FakeUserContext(h.UserId, "Tester");
        var paths = new PathService(owner, h.Content, h.Progress, h.Clock);
        var content = new ContentService(h.Content);

        var catalog = await content.GetCatalogAsync();
        var track = catalog.Tracks.Single(track => track.Id == TestContent.TrackId);
        track.LearningAvailable.Should().BeTrue();
        var users = new UserService(owner, h.Users, h.Content);
        (await users.GetOrProvisionAsync()).ActiveTrackId.Should().BeNull();
        var before = await paths.GetPathAsync(track.Id);
        (await users.GetOrProvisionAsync()).ActiveTrackId.Should().BeNull(
            "catalog and path reads must not enroll or change the selected goal");
        var selectedGoal = await users.SetActiveTrackAsync(track.Id, null);
        selectedGoal.ActiveTrackId.Should().Be(track.Id);
        var available = before.Units[0].Lessons[0];
        available.Status.Should().Be("available");
        var lesson = await content.GetLessonWithSnapshotAsync(track.Id, available.Id);
        lesson.Should().NotBeNull();
        lesson!.PublicManifestId.Should().BeNull("this fixture uses the legacy repository");
        var check = lesson.Lesson.Blocks.Single(block => block.Check is not null).Check!;
        check.Options.Select(option => option.Id).Should().Contain(selectedOption);
        var request = QuizServiceHarness.Request(
            Guid.NewGuid().ToString(),
            new AnswerDto(check.Id, check.Type, [selectedOption], 5_000));

        var first = await h.Build().SubmitAsync(lesson.Lesson.Id, request);

        var feedback = first.Results.Should().ContainSingle().Subject;
        feedback.ItemId.Should().Be(check.Id);
        feedback.ConceptId.Should().Be(check.ConceptId);
        feedback.Correct.Should().Be(correct);
        feedback.CorrectAnswer.Should().BeEquivalentTo(correct ? null : new[] { "a" });
        feedback.Explanation.Should().Be("Because a is correct.");
        first.ScorePct.Should().Be(correct ? 100 : 0);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.ActiveTrackId.Should().Be(track.Id);
        var mastery = await h.Progress.GetMasteryAsync(h.UserId, track.Id, check.ConceptId);
        mastery.Should().NotBeNull();
        var after = await paths.GetPathAsync(track.Id);
        after.Units[0].Lessons[0].Status.Should().Be("completed",
            "completion tracks reviewed concepts, not whether the answer was correct");
        after.Units[0].Lessons[1].Status.Should().Be("available");

        var replay = await h.Build().SubmitAsync(lesson.Lesson.Id, request);
        replay.Should().BeEquivalentTo(first);
        (await h.Users.GetAsync(h.UserId)).Should().BeEquivalentTo(profile);
        (await h.Progress.GetMasteryAsync(h.UserId, track.Id, check.ConceptId))
            .Should().BeEquivalentTo(mastery);
        (await paths.GetPathAsync(track.Id)).Should().BeEquivalentTo(after);
        var otherOwner = new PathService(
            new FakeUserContext("other-owner", "Other"), h.Content, h.Progress, h.Clock);
        (await otherOwner.GetPathAsync(track.Id)).Units[0].Lessons[0].Status
            .Should().Be("available");
        (await h.Attempts.GetByClientAttemptIdAsync("other-owner", request.ClientAttemptId))
            .Should().BeNull();
    }

    [Fact]
    public async Task Retrying_an_older_goal_submission_does_not_switch_the_current_goal()
    {
        var h = new QuizServiceHarness();
        var currentTrack = (await h.Content.GetTrackAsync(TestContent.TrackId))!;
        h.Content.AddTrack(currentTrack with { Id = "other-goal", Units = [] });
        h.Users.Seed(TestContent.NewProfile(h.UserId) with { ActiveTrackId = "other-goal" });
        var owner = new FakeUserContext(h.UserId, "Tester");
        var users = new UserService(owner, h.Users, h.Content);
        var paths = new PathService(owner, h.Content, h.Progress, h.Clock);
        var request = QuizServiceHarness.Request(
            "older-goal-pending-attempt", QuizServiceHarness.Answer("l1-i1", "b"));

        var first = await h.Build().SubmitAsync("l1", request);
        var profileAfterFirst = await users.GetOrProvisionAsync();
        var replay = await h.Build().SubmitAsync("l1", request);
        var historicalPath = await paths.GetPathAsync(TestContent.TrackId);

        first.Results.Should().ContainSingle().Which.Correct.Should().BeFalse();
        replay.Should().BeEquivalentTo(first);
        (await users.GetOrProvisionAsync()).Should().BeEquivalentTo(profileAfterFirst);
        profileAfterFirst.ActiveTrackId.Should().Be("other-goal");
        historicalPath.Units[0].Lessons[0].Status.Should().Be("completed");
    }

    [Fact]
    public async Task The_same_client_attempt_id_does_not_replay_another_owners_feedback_or_progress()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        h.Users.Seed(TestContent.NewProfile("other-owner"));
        var otherQuiz = new QuizService(
            new FakeUserContext("other-owner", "Other"), h.Clock, h.Content, h.Progress,
            h.Attempts, h.Events, h.Users, h.Leaderboard, h.LearnerModels, h.EconomyOperations);
        var ownerRequest = QuizServiceHarness.Request(
            "shared-client-attempt", QuizServiceHarness.Answer("l1-i1", "a"));
        var otherRequest = QuizServiceHarness.Request(
            "shared-client-attempt", QuizServiceHarness.Answer("l1-i1", "b"));

        var ownerResult = await h.Build().SubmitAsync("l1", ownerRequest);
        var ownerProfile = await h.Users.GetAsync(h.UserId);
        var otherResult = await otherQuiz.SubmitAsync("l1", otherRequest);
        var ownerReplay = await h.Build().SubmitAsync("l1", ownerRequest);
        var otherReplay = await otherQuiz.SubmitAsync("l1", otherRequest);

        ownerResult.ScorePct.Should().Be(100);
        ownerResult.Results.Should().ContainSingle().Which.CorrectAnswer.Should().BeNull();
        otherResult.ScorePct.Should().Be(0);
        otherResult.Results.Should().ContainSingle().Which.CorrectAnswer.Should().Equal("a");
        ownerReplay.Should().BeEquivalentTo(ownerResult);
        otherReplay.Should().BeEquivalentTo(otherResult);
        (await h.Users.GetAsync(h.UserId)).Should().BeEquivalentTo(ownerProfile);
        var ownerMastery = await h.Progress.GetMasteryAsync(h.UserId, TestContent.TrackId, "c1");
        var otherMastery = await h.Progress.GetMasteryAsync("other-owner", TestContent.TrackId, "c1");
        ownerMastery!.MasteryScore.Should().BeGreaterThan(otherMastery!.MasteryScore);
        h.Events.Events.Should().ContainSingle(e => e.UserId == h.UserId && e.Type == "quiz.submitted");
        h.Events.Events.Should().ContainSingle(e => e.UserId == "other-owner" && e.Type == "quiz.submitted");
    }

    [Fact]
    public async Task Submission_uses_the_fetched_manifest_after_active_content_changes()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var content = new PinnedContentRepository(h.Content);
        var fetched = await new ContentService(content)
            .GetLessonWithSnapshotAsync(TestContent.TrackId, "l1");
        fetched!.PublicManifestId.Should().Be(PinnedContentRepository.OldManifest);
        content.UseNewRelease = true;
        var quiz = new QuizService(
            new FakeUserContext(h.UserId, "Tester"), h.Clock, content, h.Progress,
            h.Attempts, h.Events, h.Users, h.Leaderboard, h.LearnerModels, h.EconomyOperations);
        var request = QuizServiceHarness.Request(
            "pinned-attempt", QuizServiceHarness.Answer("l1-i1", "a")) with
        {
            PublicManifestId = fetched.PublicManifestId,
        };

        var first = await quiz.SubmitAsync("l1", request);
        var replay = await quiz.SubmitAsync("l1", request);

        first.Results.Should().ContainSingle().Which.Correct.Should().BeTrue();
        content.LastAnswerSnapshot!.PublicManifestId.Should().Be(fetched.PublicManifestId);
        content.AnswerReads.Should().Be(1, "the idempotent retry returns its stored result");
        replay.Should().BeEquivalentTo(first);
    }

    private sealed class PinnedContentRepository(InMemoryContentRepository inner) : IContentRepository
    {
        public const string OldManifest =
            "sha256:1111111111111111111111111111111111111111111111111111111111111111";
        private const string NewManifest =
            "sha256:2222222222222222222222222222222222222222222222222222222222222222";
        public bool UseNewRelease { get; set; }
        public ContentSnapshot? LastAnswerSnapshot { get; private set; }
        public int AnswerReads { get; private set; }

        public Task<ContentSnapshot> ResolveActiveSnapshotAsync(CancellationToken cancellationToken = default)
            => ResolveSnapshotAsync(UseNewRelease ? NewManifest : OldManifest, cancellationToken);

        public Task<ContentSnapshot> ResolveSnapshotAsync(
            string publicManifestId, CancellationToken cancellationToken = default)
            => publicManifestId is OldManifest or NewManifest
                ? Task.FromResult(new ContentSnapshot(
                    ContentReleaseContracts.VersionedSource,
                    publicManifestId == OldManifest ? "old-release" : "new-release",
                    publicManifestId))
                : throw new ContentReleaseNotFoundException("Unknown synthetic manifest.");

        public async Task<LessonAnswerKey?> GetAnswerKeyAsync(
            ContentSnapshot snapshot, string trackId, string lessonId,
            CancellationToken cancellationToken = default)
        {
            LastAnswerSnapshot = snapshot;
            AnswerReads++;
            var key = await inner.GetAnswerKeyAsync(trackId, lessonId, cancellationToken);
            return key is null || snapshot.PublicManifestId == OldManifest
                ? key
                : key with { Items = key.Items.Select(item => item with { Correct = ["b"] }).ToArray() };
        }

        public Task<Track?> GetTrackAsync(string trackId, CancellationToken cancellationToken = default)
            => inner.GetTrackAsync(trackId, cancellationToken);
        public Task<Lesson?> GetLessonAsync(
            string trackId, string lessonId, CancellationToken cancellationToken = default)
            => inner.GetLessonAsync(trackId, lessonId, cancellationToken);
        public Task<LessonAnswerKey?> GetAnswerKeyAsync(
            string trackId, string lessonId, CancellationToken cancellationToken = default)
            => throw new InvalidOperationException("The quiz must use the snapshot-aware answer-key read.");
        public Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(
            string trackId, CancellationToken cancellationToken = default)
            => inner.ListAnswerKeysAsync(trackId, cancellationToken);
        public Task<IReadOnlyList<Track>> ListTracksAsync(CancellationToken cancellationToken = default)
            => inner.ListTracksAsync(cancellationToken);
    }
}
