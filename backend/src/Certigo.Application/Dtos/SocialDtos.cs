namespace Certigo.Application.Dtos;

// --- Friends / social ------------------------------------------------------

public sealed record FriendDto(
    string UserId,
    string DisplayName,
    string Handle,
    string? AvatarUrl,
    int Level,
    int StreakDays,
    int Xp,
    DateTimeOffset FriendsSince);

public sealed record FriendListDto(int Count, IReadOnlyList<FriendDto> Friends);

public sealed record AddFriendRequest(string Handle);

public sealed record FriendActionResultDto(
    bool Success,
    string? FriendUserId,
    string? Error,
    FriendListDto Friends);

public sealed record FriendLeaderboardDto(
    string MeUserId,
    IReadOnlyList<LeaderboardEntryDto> Entries);
