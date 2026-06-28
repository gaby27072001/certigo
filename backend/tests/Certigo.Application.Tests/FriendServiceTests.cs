using FluentAssertions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class FriendServiceTests
{
    private const string UserId = "user-1";
    private static readonly DateTimeOffset Now = new(2025, 1, 6, 12, 0, 0, TimeSpan.Zero);

    private static (FriendService Service, InMemoryUserRepository Users, InMemoryFriendRepository Friends, InMemoryEventRepository Events) Build()
    {
        var users = new InMemoryUserRepository();
        var friends = new InMemoryFriendRepository();
        var events = new InMemoryEventRepository();
        var context = new FakeUserContext(UserId, "Tester");
        var service = new FriendService(context, new FakeClock(Now), users, friends, events);
        return (service, users, friends, events);
    }

    private static UserProfileDto Profile(string id, string handle, int xp = 0, int streak = 0, int level = 1)
        => TestContent.NewProfile(id) with { DisplayName = id, Handle = handle, Xp = xp, StreakDays = streak, Level = level };

    [Fact]
    public async Task AddByHandleAsync_creates_a_mutual_friendship_and_emits_event()
    {
        var (service, users, friends, events) = Build();
        users.Seed(Profile(UserId, "tester"));
        users.Seed(Profile("user-2", "bob", xp: 120, streak: 4, level: 2));

        var result = await service.AddByHandleAsync("bob");

        result.Success.Should().BeTrue();
        result.FriendUserId.Should().Be("user-2");
        result.Friends.Count.Should().Be(1);
        result.Friends.Friends[0].Handle.Should().Be("bob");
        result.Friends.Friends[0].Xp.Should().Be(120);
        result.Friends.Friends[0].StreakDays.Should().Be(4);
        result.Friends.Friends[0].FriendsSince.Should().Be(Now);

        (await friends.GetAsync(UserId, "user-2")).Should().NotBeNull();
        (await friends.GetAsync("user-2", UserId)).Should().NotBeNull();
        events.Events.Should().ContainSingle(e => e.Type == "friend.added");
    }

    [Fact]
    public async Task AddByHandleAsync_is_idempotent_and_normalizes_handle()
    {
        var (service, users, _, events) = Build();
        users.Seed(Profile(UserId, "tester"));
        users.Seed(Profile("user-2", "bob"));

        await service.AddByHandleAsync("bob");
        var second = await service.AddByHandleAsync("@BOB");

        second.Success.Should().BeTrue();
        second.Friends.Count.Should().Be(1);
        events.Events.Count(e => e.Type == "friend.added").Should().Be(1);
    }

    [Fact]
    public async Task AddByHandleAsync_with_unknown_handle_fails_not_found()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(UserId, "tester"));

        var result = await service.AddByHandleAsync("ghost");

        result.Success.Should().BeFalse();
        result.Error.Should().Be("not_found");
        result.Friends.Count.Should().Be(0);
    }

    [Fact]
    public async Task AddByHandleAsync_rejects_self()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(UserId, "tester"));

        var result = await service.AddByHandleAsync("tester");

        result.Success.Should().BeFalse();
        result.Error.Should().Be("self");
    }

    [Fact]
    public async Task RemoveAsync_unfriends_in_both_directions()
    {
        var (service, users, friends, _) = Build();
        users.Seed(Profile(UserId, "tester"));
        users.Seed(Profile("user-2", "bob"));
        await service.AddByHandleAsync("bob");

        var result = await service.RemoveAsync("user-2");

        result.Friends.Count.Should().Be(0);
        (await friends.GetAsync(UserId, "user-2")).Should().BeNull();
        (await friends.GetAsync("user-2", UserId)).Should().BeNull();
    }

    [Fact]
    public async Task LeaderboardAsync_ranks_self_and_friends_by_xp()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(UserId, "tester", xp: 50));
        users.Seed(Profile("user-2", "bob", xp: 120));
        users.Seed(Profile("user-3", "cara", xp: 80));
        await service.AddByHandleAsync("bob");
        await service.AddByHandleAsync("cara");

        var board = await service.LeaderboardAsync();

        board.MeUserId.Should().Be(UserId);
        board.Entries.Should().HaveCount(3);
        board.Entries[0].UserId.Should().Be("user-2");
        board.Entries[0].Rank.Should().Be(1);
        board.Entries[1].UserId.Should().Be("user-3");
        board.Entries[2].UserId.Should().Be(UserId);
    }
}
