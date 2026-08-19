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
}
