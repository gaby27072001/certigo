using FluentAssertions;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;
using Xunit;

namespace Microlingo.Application.Tests;

/// <summary>
/// Tests du <see cref="NotificationService"/> : il orchestre l'apprentissage de
/// l'heure d'activité (idempotent par jour), borne les préférences, et projette
/// un plan de notifications déterministe à partir des signaux d'engagement et de
/// la ligue. La logique pure de planification est déjà couverte par les tests
/// domaine ; on vérifie ici le câblage et les effets de bord persistés.
/// </summary>
public sealed class NotificationServiceTests
{
    private static readonly DateTimeOffset Now = new(2026, 6, 23, 18, 0, 0, TimeSpan.Zero);
    private static readonly DateOnly Today = new(2026, 6, 23);

    private sealed record Harness(
        NotificationService Service,
        InMemoryUserRepository Users,
        InMemoryEventRepository Events,
        StubLeaderboardService Leaderboard);

    private static Harness Build(UserProfileDto? profile = null, DateTimeOffset? now = null)
    {
        var users = new InMemoryUserRepository();
        if (profile is not null)
        {
            users.Seed(profile);
        }

        var events = new InMemoryEventRepository();
        var leaderboard = new StubLeaderboardService();
        var service = new NotificationService(
            new FakeUserContext("u1", "Alice"),
            new FakeClock(now ?? Now),
            users,
            leaderboard,
            events);

        return new Harness(service, users, events, leaderboard);
    }

    private static UserProfileDto Profile() => TestContent.NewProfile("u1");

    private static int ActivityObserved(InMemoryEventRepository events)
        => events.Events.Count(e => e.Type == "notification.activityObserved");

    [Fact]
    public async Task GetPlanAsync_NouvelUtilisateur_PlanifieSurLeJourUtc()
    {
        var h = Build();

        var plan = await h.Service.GetPlanAsync();

        plan.LocalDate.Should().Be(Today);
        plan.Notifications.Should().NotBeEmpty();
        plan.Notifications.Should().Contain(n => n.Kind == "DailyReminder");
        plan.Notifications.Should().OnlyContain(n =>
            n.Kind.Length > 0 &&
            n.Priority.Length > 0 &&
            n.Mascot.Length > 0 &&
            n.Title.Length > 0 &&
            n.Body.Length > 0 &&
            n.Deeplink.Length > 0 &&
            n.DedupeKey.Length > 0);
    }

    [Fact]
    public async Task GetPlanAsync_NotificationsDesactivees_RetournePlanVide()
    {
        var profile = Profile() with
        {
            NotificationState = new NotificationStateDto(NotificationSettingsDto.Default with { Enabled = false }),
        };
        var h = Build(profile);

        var plan = await h.Service.GetPlanAsync();

        plan.LocalDate.Should().Be(Today);
        plan.Notifications.Should().BeEmpty();
    }

    [Fact]
    public async Task GetPlanAsync_PratiqueAujourdhui_ApprendLheureUneSeuleFoisParJour()
    {
        var profile = Profile() with
        {
            DailyXpDate = Today,
            DailyXpEarned = 30,
        };
        var h = Build(profile);

        await h.Service.GetPlanAsync();

        ActivityObserved(h.Events).Should().Be(1);
        var afterFirst = await h.Users.GetAsync("u1");
        afterFirst!.NotificationState.Should().NotBeNull();
        afterFirst.NotificationState!.ActivityHours.Should().NotBeNull();
        afterFirst.NotificationState!.ActivityHours![18].Should().Be(8);
        afterFirst.NotificationState!.ActivityHours!.Where((_, hour) => hour != 18)
            .Should().OnlyContain(v => v == 0);
        afterFirst.NotificationState!.LastActivityHourDate.Should().Be(Today);

        await h.Service.GetPlanAsync();

        ActivityObserved(h.Events).Should().Be(1);
        var afterSecond = await h.Users.GetAsync("u1");
        afterSecond!.NotificationState!.ActivityHours![18].Should().Be(8);
    }

    [Fact]
    public async Task GetPlanAsync_PasDePratique_NApprendPas()
    {
        var h = Build(Profile());

        await h.Service.GetPlanAsync();

        ActivityObserved(h.Events).Should().Be(0);
        var after = await h.Users.GetAsync("u1");
        after!.NotificationState.Should().BeNull();
    }

    [Fact]
    public async Task GetSettingsAsync_SansEtat_RetourneLesDefauts()
    {
        var h = Build(Profile());

        var settings = await h.Service.GetSettingsAsync();

        settings.Should().Be(NotificationSettingsDto.Default);
    }

    [Fact]
    public async Task GetSettingsAsync_AvecEtat_RetourneLesPreferencesPersistees()
    {
        var custom = NotificationSettingsDto.Default with { PreferredHour = 8, MaxPerDay = 1 };
        var profile = Profile() with { NotificationState = new NotificationStateDto(custom) };
        var h = Build(profile);

        var settings = await h.Service.GetSettingsAsync();

        settings.Should().Be(custom);
    }

    [Fact]
    public async Task UpdateSettingsAsync_BorneLesValeursHorsLimites()
    {
        var h = Build(Profile());
        var request = new UpdateNotificationSettingsRequest(
            Enabled: true,
            UtcOffsetMinutes: 99999,
            QuietHoursStart: -5,
            QuietHoursEnd: 50,
            PreferredHour: 30,
            MaxPerDay: 99,
            StreakAlerts: true,
            QuestAlerts: false,
            LeagueAlerts: true);

        var settings = await h.Service.UpdateSettingsAsync(request);

        settings.UtcOffsetMinutes.Should().Be(840);
        settings.QuietHoursStart.Should().Be(19);
        settings.QuietHoursEnd.Should().Be(2);
        settings.PreferredHour.Should().Be(6);
        settings.MaxPerDay.Should().Be(10);
        settings.QuestAlerts.Should().BeFalse();

        var persisted = await h.Users.GetAsync("u1");
        persisted!.NotificationState!.Settings.Should().Be(settings);
        h.Events.Events.Should().ContainSingle(e => e.Type == "notification.settingsUpdated");
    }

    [Fact]
    public async Task UpdateSettingsAsync_PreserveLhistogrammeAppris()
    {
        var histogram = new List<int>(new int[24]);
        histogram[9] = 8;
        var profile = Profile() with
        {
            NotificationState = new NotificationStateDto(NotificationSettingsDto.Default, histogram, Today),
        };
        var h = Build(profile);

        var request = new UpdateNotificationSettingsRequest(
            Enabled: true,
            UtcOffsetMinutes: 60,
            QuietHoursStart: 23,
            QuietHoursEnd: 6,
            PreferredHour: 8,
            MaxPerDay: 2,
            StreakAlerts: true,
            QuestAlerts: true,
            LeagueAlerts: true);

        await h.Service.UpdateSettingsAsync(request);

        var persisted = await h.Users.GetAsync("u1");
        persisted!.NotificationState!.ActivityHours.Should().Equal(histogram);
        persisted.NotificationState!.LastActivityHourDate.Should().Be(Today);
        persisted.NotificationState!.Settings.PreferredHour.Should().Be(8);
    }

    [Theory]
    [InlineData("promotion", true)]
    [InlineData("relegation", true)]
    [InlineData("safe", false)]
    public async Task GetPlanAsync_ZoneDeLigue_PiloteLeRappelDeLigue(string zone, bool expectNudge)
    {
        var h = Build(Profile());
        h.Leaderboard.MyZone = zone;
        h.Leaderboard.MyRank = 5;
        h.Leaderboard.EntryCount = 10;

        var plan = await h.Service.GetPlanAsync();

        plan.Notifications.Any(n => n.Kind == "LeagueNudge").Should().Be(expectNudge);
    }

    [Fact]
    public async Task GetPlanAsync_LigueVide_NeProduitPasDeRappelDeLigue()
    {
        var h = Build(Profile());
        h.Leaderboard.MyZone = "relegation";
        h.Leaderboard.MyRank = 0;
        h.Leaderboard.EntryCount = 0;

        var plan = await h.Service.GetPlanAsync();

        plan.Notifications.Should().NotContain(n => n.Kind == "LeagueNudge");
    }
}
