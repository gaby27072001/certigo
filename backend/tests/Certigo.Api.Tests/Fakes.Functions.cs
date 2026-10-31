using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;

namespace Certigo.Api.Tests;

// Additional hand-rolled doubles for the 15 application services exercised by the
// HTTP function coverage tests. Same convention as Fakes.cs: internal sealed, no
// mocking library, capture call arguments / counts as public properties, and expose
// a configurable Result wired from a DefaultResult() factory built on the real DTO
// constructors (Certigo.Application.Dtos.Dtos.cs).

/// <summary>Double for <see cref="IUserService"/>.</summary>
internal sealed class FakeUserService : IUserService
{
    public UserProfileDto Result { get; set; } = DefaultResult();

    public int CallCount { get; private set; }
    public int SetActiveTrackCallCount { get; private set; }
    public string? LastTrackId { get; private set; }
    public string? LastExpectedTrackId { get; private set; }

    public Task<UserProfileDto> GetOrProvisionAsync(CancellationToken cancellationToken = default)
    {
        CallCount++;
        return Task.FromResult(Result);
    }

    public Task<UserProfileDto> SetActiveTrackAsync(
        string trackId,
        string? expectedTrackId,
        CancellationToken cancellationToken = default)
    {
        SetActiveTrackCallCount++;
        LastTrackId = trackId;
        LastExpectedTrackId = expectedTrackId;
        Result = Result with { ActiveTrackId = trackId };
        return Task.FromResult(Result);
    }

    private static UserProfileDto DefaultResult() =>
        new("user-1", "Test User", "testuser", null, 0, 1, 0, 0, 50, 0, 0, null);
}

/// <summary>Double for <see cref="ITutorService"/>.</summary>
internal sealed class FakeTutorService : ITutorService
{
    public TutorExplanationDto Result { get; set; } = DefaultResult();

    public TutorChatResponseDto ChatResult { get; set; } = DefaultChatResult();

    public TutorExplainRequest? LastRequest { get; private set; }

    public TutorChatRequest? LastChatRequest { get; private set; }

    public int CallCount { get; private set; }

    public int ChatCallCount { get; private set; }

    public Task<TutorExplanationDto> ExplainAsync(TutorExplainRequest request, CancellationToken cancellationToken = default)
    {
        LastRequest = request;
        CallCount++;
        return Task.FromResult(Result);
    }

    public Task<TutorChatResponseDto> ChatAsync(TutorChatRequest request, CancellationToken cancellationToken = default)
    {
        LastChatRequest = request;
        ChatCallCount++;
        return Task.FromResult(ChatResult);
    }

    private static TutorExplanationDto DefaultResult() =>
        new(
            "item-1",
            "concept-1",
            true,
            "Bien vu",
            new List<string> { "point" },
            "Continue",
            "Revois X",
            new List<string> { "concept-1" },
            "ai",
            new TutorPersonalizationDto(1, 0, 100, false, false, "flat", null));

    private static TutorChatResponseDto DefaultChatResult() =>
        new(
            "Bonjour ! Voici la réponse.",
            new List<string> { "Question 1", "Question 2" },
            "ai",
            "gpt-5.4-mini");
}

/// <summary>Double for <see cref="IStreakRepairService"/>.</summary>
internal sealed class FakeStreakRepairService : IStreakRepairService
{
    public StreakStatusDto StatusResult { get; set; } = DefaultStatus();

    public StreakRepairResultDto RepairResult { get; set; } = DefaultRepair();

    public StreakRepairRequest? LastRepair { get; private set; }

    public int StatusCallCount { get; private set; }

    public int RepairCallCount { get; private set; }

    public Task<StreakStatusDto> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        StatusCallCount++;
        return Task.FromResult(StatusResult);
    }

    public Task<StreakRepairResultDto> RepairAsync(StreakRepairRequest request, CancellationToken cancellationToken = default)
    {
        LastRepair = request;
        RepairCallCount++;
        return Task.FromResult(RepairResult);
    }

    private static StreakStatusDto DefaultStatus() =>
        new(5, new DateOnly(2025, 1, 5), 1, true, 10, null);

    private static StreakRepairResultDto DefaultRepair() =>
        new(true, 6, 10, 40, new DateOnly(2025, 1, 6), null);
}

/// <summary>Double for <see cref="IShopService"/>.</summary>
internal sealed class FakeShopService : IShopService
{
    public ShopCatalogDto CatalogResult { get; set; } = DefaultCatalog();

    public PurchaseResultDto PurchaseResult { get; set; } = DefaultPurchase();

    public PurchaseRequest? LastPurchase { get; private set; }

    public int CatalogCallCount { get; private set; }

    public int PurchaseCallCount { get; private set; }

    public Task<ShopCatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default)
    {
        CatalogCallCount++;
        return Task.FromResult(CatalogResult);
    }

    public Task<PurchaseResultDto> PurchaseAsync(PurchaseRequest request, CancellationToken cancellationToken = default)
    {
        LastPurchase = request;
        PurchaseCallCount++;
        return Task.FromResult(PurchaseResult);
    }

    private static ShopCatalogDto DefaultCatalog() =>
        new(100, new List<ShopItemDto>());

    private static PurchaseResultDto DefaultPurchase() =>
        new(true, "item-1", 20, 80, 1, null);
}

/// <summary>Double for <see cref="IQuestService"/>.</summary>
internal sealed class FakeQuestService : IQuestService
{
    public QuestBoardDto BoardResult { get; set; } = DefaultBoard();

    public ClaimQuestResultDto ClaimResult { get; set; } = DefaultClaim();

    public ClaimQuestRequest? LastClaim { get; private set; }

    public int BoardCallCount { get; private set; }

    public int ClaimCallCount { get; private set; }

    public Task<QuestBoardDto> GetTodayAsync(CancellationToken cancellationToken = default)
    {
        BoardCallCount++;
        return Task.FromResult(BoardResult);
    }

    public Task<ClaimQuestResultDto> ClaimAsync(ClaimQuestRequest request, CancellationToken cancellationToken = default)
    {
        LastClaim = request;
        ClaimCallCount++;
        return Task.FromResult(ClaimResult);
    }

    private static QuestBoardDto DefaultBoard() =>
        new(new DateOnly(2025, 1, 6), 0, new List<QuestDto>());

    private static ClaimQuestResultDto DefaultClaim() =>
        new(true, "quest-1", 20, 20, true, null);
}

/// <summary>Double for <see cref="ISeasonService"/>.</summary>
internal sealed class FakeSeasonService : ISeasonService
{
    public SeasonDto SeasonResult { get; set; } = DefaultSeason();

    public ClaimSeasonResultDto ClaimResult { get; set; } = DefaultClaim();

    public ClaimSeasonRequest? LastClaim { get; private set; }

    public int SeasonCallCount { get; private set; }

    public int ClaimCallCount { get; private set; }

    public Task<SeasonDto> GetCurrentAsync(CancellationToken cancellationToken = default)
    {
        SeasonCallCount++;
        return Task.FromResult(SeasonResult);
    }

    public Task<ClaimSeasonResultDto> ClaimAsync(ClaimSeasonRequest request, CancellationToken cancellationToken = default)
    {
        LastClaim = request;
        ClaimCallCount++;
        return Task.FromResult(ClaimResult);
    }

    private static SeasonDto DefaultSeason() =>
        new(
            "season-1",
            2025,
            1,
            "Theme",
            "Tagline",
            "mascot",
            "#ffffff",
            "badge-1",
            "Badge",
            100,
            0,
            new SeasonChallengeDto("xp", "Title", 100, 0, 50, false, false, false));

    private static ClaimSeasonResultDto DefaultClaim() =>
        new(true, "season-1", "badge-1", 50, 150, true, null);
}

/// <summary>Double for <see cref="IAchievementService"/>.</summary>
internal sealed class FakeAchievementService : IAchievementService
{
    public AchievementBoardDto Result { get; set; } = DefaultResult();

    public int CallCount { get; private set; }

    public Task<AchievementBoardDto> GetAllAsync(CancellationToken cancellationToken = default)
    {
        CallCount++;
        return Task.FromResult(Result);
    }

    private static AchievementBoardDto DefaultResult() =>
        new(0, 10, new List<AchievementDto>());
}

/// <summary>Double for <see cref="IShareCardService"/>.</summary>
internal sealed class FakeShareCardService : IShareCardService
{
    public ShareCardDto Result { get; set; } = DefaultResult();

    public int CallCount { get; private set; }

    public Task<ShareCardDto> GetDailyAsync(CancellationToken cancellationToken = default)
    {
        CallCount++;
        return Task.FromResult(Result);
    }

    private static ShareCardDto DefaultResult() =>
        new(
            "share-1",
            "Test User",
            "testuser",
            5,
            2,
            30,
            50,
            false,
            60,
            "AZ-900",
            "mascot",
            "Headline",
            "Caption",
            "REF123",
            DateTimeOffset.UnixEpoch);
}

/// <summary>Double for <see cref="IFriendService"/>.</summary>
internal sealed class FakeFriendService : IFriendService
{
    public FriendListDto ListResult { get; set; } = DefaultList();

    public FriendActionResultDto AddResult { get; set; } = DefaultAction();

    public FriendActionResultDto RemoveResult { get; set; } = DefaultAction();

    public FriendLeaderboardDto LeaderboardResult { get; set; } = DefaultLeaderboard();

    public string? LastAddedHandle { get; private set; }

    public string? LastRemovedUserId { get; private set; }

    public int ListCallCount { get; private set; }

    public int AddCallCount { get; private set; }

    public int RemoveCallCount { get; private set; }

    public int LeaderboardCallCount { get; private set; }

    public Task<FriendListDto> ListAsync(CancellationToken cancellationToken = default)
    {
        ListCallCount++;
        return Task.FromResult(ListResult);
    }

    public Task<FriendActionResultDto> AddByHandleAsync(string handle, CancellationToken cancellationToken = default)
    {
        LastAddedHandle = handle;
        AddCallCount++;
        return Task.FromResult(AddResult);
    }

    public Task<FriendActionResultDto> RemoveAsync(string friendUserId, CancellationToken cancellationToken = default)
    {
        LastRemovedUserId = friendUserId;
        RemoveCallCount++;
        return Task.FromResult(RemoveResult);
    }

    public Task<FriendLeaderboardDto> LeaderboardAsync(CancellationToken cancellationToken = default)
    {
        LeaderboardCallCount++;
        return Task.FromResult(LeaderboardResult);
    }

    private static FriendListDto DefaultList() =>
        new(0, new List<FriendDto>());

    private static FriendActionResultDto DefaultAction() =>
        new(true, "friend-1", null, new FriendListDto(1, new List<FriendDto>()));

    private static FriendLeaderboardDto DefaultLeaderboard() =>
        new("user-1", new List<LeaderboardEntryDto>());
}

/// <summary>Double for <see cref="ILeaderboardService"/>.</summary>
internal sealed class FakeLeaderboardService : ILeaderboardService
{
    public LeagueDto LeagueResult { get; set; } = DefaultLeague();

    public LeagueResolutionDto ResolutionResult { get; set; } = DefaultResolution();

    public int LeagueCallCount { get; private set; }

    public int ResolutionCallCount { get; private set; }

    public Task<LeagueDto> GetMyLeagueAsync(CancellationToken cancellationToken = default)
    {
        LeagueCallCount++;
        return Task.FromResult(LeagueResult);
    }

    public Task<LeagueResolutionDto> PreviewResolutionAsync(CancellationToken cancellationToken = default)
    {
        ResolutionCallCount++;
        return Task.FromResult(ResolutionResult);
    }

    private static LeagueDto DefaultLeague() =>
        new("league-1", "Bronze", DateTimeOffset.UnixEpoch, 3, "user-1", new List<LeaderboardEntryDto>());

    private static LeagueResolutionDto DefaultResolution() =>
        new("league-1", "Bronze", new List<LeagueOutcomeDto>());
}

/// <summary>Double for <see cref="IPathService"/>.</summary>
internal sealed class FakePathService : IPathService
{
    public PathDto Result { get; set; } = DefaultResult();

    public string? LastTrackId { get; private set; }

    public int CallCount { get; private set; }

    public Task<PathDto> GetPathAsync(string trackId, CancellationToken cancellationToken = default)
    {
        LastTrackId = trackId;
        CallCount++;
        return Task.FromResult(Result);
    }

    private static PathDto DefaultResult() =>
        new("track-1", "Azure Fundamentals", "AZ-900", 60, 5, new List<PathUnitDto>(), new List<DomainProgressDto>());
}

/// <summary>Double for <see cref="IRecommendationService"/>.</summary>
internal sealed class FakeRecommendationService : IRecommendationService
{
    public NextBestDto Result { get; set; } = DefaultResult();

    public string? LastTrackId { get; private set; }

    public int CallCount { get; private set; }

    public Task<NextBestDto> GetNextBestAsync(string trackId, CancellationToken cancellationToken = default)
    {
        LastTrackId = trackId;
        CallCount++;
        return Task.FromResult(Result);
    }

    private static NextBestDto DefaultResult() =>
        new("track-1", DateTimeOffset.UnixEpoch, new List<RecommendationItemDto>());
}

/// <summary>Double for <see cref="INotificationService"/>.</summary>
internal sealed class FakeNotificationService : INotificationService
{
    public NotificationPlanDto PlanResult { get; set; } = DefaultPlan();

    public NotificationSettingsDto SettingsResult { get; set; } = NotificationSettingsDto.Default;

    public NotificationSettingsDto UpdateResult { get; set; } = NotificationSettingsDto.Default;

    public UpdateNotificationSettingsRequest? LastUpdate { get; private set; }

    public int PlanCallCount { get; private set; }

    public int SettingsCallCount { get; private set; }

    public int UpdateCallCount { get; private set; }

    public Task<NotificationPlanDto> GetPlanAsync(CancellationToken cancellationToken = default)
    {
        PlanCallCount++;
        return Task.FromResult(PlanResult);
    }

    public Task<NotificationSettingsDto> GetSettingsAsync(CancellationToken cancellationToken = default)
    {
        SettingsCallCount++;
        return Task.FromResult(SettingsResult);
    }

    public Task<NotificationSettingsDto> UpdateSettingsAsync(UpdateNotificationSettingsRequest request, CancellationToken cancellationToken = default)
    {
        LastUpdate = request;
        UpdateCallCount++;
        return Task.FromResult(UpdateResult);
    }

    private static NotificationPlanDto DefaultPlan() =>
        new(new DateOnly(2025, 1, 6), new List<ScheduledNotificationDto>());
}

/// <summary>Double for <see cref="IContentService"/>. Lesson is nullable so the 404 branch is testable.</summary>
internal sealed class FakeContentService : IContentService
{
    public Lesson? LessonResult { get; set; } = DefaultLesson();
    public string? PublicManifestId { get; set; }

    public CatalogDto CatalogResult { get; set; } = DefaultCatalog();

    public string? LastTrackId { get; private set; }

    public string? LastLessonId { get; private set; }

    public int LessonCallCount { get; private set; }

    public int CatalogCallCount { get; private set; }

    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
    {
        LastTrackId = trackId;
        LastLessonId = lessonId;
        LessonCallCount++;
        return Task.FromResult(LessonResult);
    }

    public async Task<ContentLessonResult?> GetLessonWithSnapshotAsync(
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
    {
        var lesson = await GetLessonAsync(trackId, lessonId, cancellationToken);
        return lesson is null ? null : new ContentLessonResult(lesson, PublicManifestId);
    }

    public Task<CatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default)
    {
        CatalogCallCount++;
        return Task.FromResult(CatalogResult);
    }

    private static Lesson DefaultLesson() =>
        new("lesson-1", "track-1", "unit-1", "domain-1", "Title", 5, new List<LessonBlock>());

    private static CatalogDto DefaultCatalog() =>
        new(
            CertificationCatalogSchemas.AppV2,
            CertificationCatalogSchemas.SourceV1,
            null,
            null,
            Array.Empty<CertificationProviderDto>(),
            Array.Empty<TrackSummaryDto>());
}

/// <summary>Double for <see cref="IExamService"/>.</summary>
internal sealed class FakeExamService : IExamService
{
    public MockExamDto GenerateResult { get; set; } = DefaultGenerate();

    public MockExamResultDto SubmitResult { get; set; } = DefaultSubmit();

    public MockExamRequest? LastGenerate { get; private set; }

    public SubmitMockExamRequest? LastSubmit { get; private set; }

    public int GenerateCallCount { get; private set; }

    public int SubmitCallCount { get; private set; }

    public Task<MockExamDto> GenerateAsync(MockExamRequest request, CancellationToken cancellationToken = default)
    {
        LastGenerate = request;
        GenerateCallCount++;
        return Task.FromResult(GenerateResult);
    }

    public Task<MockExamResultDto> SubmitAsync(SubmitMockExamRequest request, CancellationToken cancellationToken = default)
    {
        LastSubmit = request;
        SubmitCallCount++;
        return Task.FromResult(SubmitResult);
    }

    private static MockExamDto DefaultGenerate() =>
        new(
            "exam-1",
            "track-1",
            "AZ-900",
            "Azure Fundamentals",
            3600,
            70,
            new List<MockExamBlueprintDomainDto>(),
            new List<MockExamItemDto>());

    private static MockExamResultDto DefaultSubmit() =>
        new(
            "attempt-1",
            "exam-1",
            700,
            70,
            true,
            70,
            7,
            10,
            new List<ExamDomainScoreDto>(),
            new List<ItemResultDto>(),
            new RewardsDto(10, 110, false, false, 2, new List<string>()),
            new List<string>());
}
