using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class UserServiceTests
{
    [Fact]
    public async Task SetActiveTrackAsync_PersistsPublishedTrackWithoutChangingOtherProfileData()
    {
        var users = new InMemoryUserRepository();
        var content = TestContent.Build();
        var context = new FakeUserContext("user-1", "Learner");
        var service = new UserService(context, users, content);
        var original = await service.GetOrProvisionAsync();

        var updated = await service.SetActiveTrackAsync(TestContent.TrackId, null);

        updated.ActiveTrackId.Should().Be(TestContent.TrackId);
        updated.DisplayName.Should().Be(original.DisplayName);
        updated.Xp.Should().Be(original.Xp);
        (await users.GetAsync(context.UserId))!.ActiveTrackId.Should().Be(TestContent.TrackId);
    }

    [Fact]
    public async Task SetActiveTrackAsync_RejectsTrackMissingFromPublishedContent()
    {
        var service = new UserService(
            new FakeUserContext("user-1", "Learner"),
            new InMemoryUserRepository(),
            TestContent.Build());

        var act = () => service.SetActiveTrackAsync("missing", null);

        await act.Should().ThrowAsync<TrackNotFoundException>();
    }

    [Fact]
    public async Task SetActiveTrackAsync_rejects_a_stale_expected_track()
    {
        var users = new InMemoryUserRepository();
        var content = TestContent.Build();
        var context = new FakeUserContext("user-1", "Learner");
        var service = new UserService(context, users, content);
        users.Seed(TestContent.NewProfile(context.UserId) with { ActiveTrackId = "dp-900" });

        var act = () => service.SetActiveTrackAsync(TestContent.TrackId, "sc-900");

        await act.Should().ThrowAsync<ActiveTrackConflictException>();
    }

    [Fact]
    public async Task SetActiveTrackAsync_is_idempotent_after_an_ambiguous_retry()
    {
        var users = new InMemoryUserRepository();
        var content = TestContent.Build();
        var context = new FakeUserContext("user-1", "Learner");
        var service = new UserService(context, users, content);
        var original = users.Seed(TestContent.NewProfile(context.UserId))!;

        var result = await service.SetActiveTrackAsync(TestContent.TrackId, null);

        result.ActiveTrackId.Should().Be(TestContent.TrackId);
        result.ETag.Should().Be(original.ETag);
    }

    [Fact]
    public async Task SetActiveTrackAsync_replays_a_real_switch_without_a_second_profile_write()
    {
        var users = new InMemoryUserRepository();
        var context = new FakeUserContext("user-1", "Learner");
        var service = new UserService(context, users, TestContent.Build());
        var original = users.Seed(TestContent.NewProfile(context.UserId) with
        {
            ActiveTrackId = null,
        })!;

        var first = await service.SetActiveTrackAsync(TestContent.TrackId, null);
        var replay = await service.SetActiveTrackAsync(TestContent.TrackId, null);

        first.ETag.Should().NotBe(original.ETag, "the first selection must actually persist");
        replay.Should().BeEquivalentTo(first);
        (await users.GetAsync(context.UserId)).Should().BeEquivalentTo(first);
    }

    [Fact]
    public async Task SetActiveTrackAsync_preserves_concurrent_rewards_when_retrying_the_same_goal_change()
    {
        var users = new InMemoryUserRepository();
        var context = new FakeUserContext("user-1", "Learner");
        users.Seed(TestContent.NewProfile(context.UserId) with { ActiveTrackId = null, Xp = 10 });
        var concurrent = new BumpThenConflictUserRepository(users, profile => profile with { Xp = 30 });
        var service = new UserService(context, concurrent, TestContent.Build());

        var result = await service.SetActiveTrackAsync(TestContent.TrackId, null);

        result.ActiveTrackId.Should().Be(TestContent.TrackId);
        result.Xp.Should().Be(30);
        concurrent.UpsertCalls.Should().Be(2);
    }

    [Fact]
    public async Task SetActiveTrackAsync_does_not_overwrite_a_goal_selected_by_another_device()
    {
        var users = new InMemoryUserRepository();
        var context = new FakeUserContext("user-1", "Learner");
        users.Seed(TestContent.NewProfile(context.UserId) with { ActiveTrackId = null });
        var concurrent = new BumpThenConflictUserRepository(
            users, profile => profile with { ActiveTrackId = "other-device-goal" });
        var service = new UserService(context, concurrent, TestContent.Build());

        var act = () => service.SetActiveTrackAsync(TestContent.TrackId, null);

        await act.Should().ThrowAsync<ActiveTrackConflictException>();
        (await users.GetAsync(context.UserId))!.ActiveTrackId.Should().Be("other-device-goal");
        concurrent.UpsertCalls.Should().Be(1);
    }

    [Fact]
    public async Task SetActiveTrackAsync_returns_a_concurrently_selected_target_without_rewriting_it()
    {
        var users = new InMemoryUserRepository();
        var context = new FakeUserContext("user-1", "Learner");
        users.Seed(TestContent.NewProfile(context.UserId) with { ActiveTrackId = null });
        var concurrent = new BumpThenConflictUserRepository(
            users, profile => profile with { ActiveTrackId = TestContent.TrackId, Xp = 25 });
        var service = new UserService(context, concurrent, TestContent.Build());

        var result = await service.SetActiveTrackAsync(TestContent.TrackId, null);

        result.ActiveTrackId.Should().Be(TestContent.TrackId);
        result.Xp.Should().Be(25);
        concurrent.UpsertCalls.Should().Be(1);
    }

    [Fact]
    public async Task SetActiveTrackAsync_only_changes_the_authenticated_owner()
    {
        var users = new InMemoryUserRepository();
        var owner = users.Seed(TestContent.NewProfile("owner") with { ActiveTrackId = null })!;
        var other = users.Seed(TestContent.NewProfile("other") with { ActiveTrackId = null })!;
        var service = new UserService(new FakeUserContext(owner.Id, "Owner"), users, TestContent.Build());

        await service.SetActiveTrackAsync(TestContent.TrackId, null);

        (await users.GetAsync(owner.Id))!.ActiveTrackId.Should().Be(TestContent.TrackId);
        (await users.GetAsync(other.Id)).Should().BeEquivalentTo(other);
    }
}
