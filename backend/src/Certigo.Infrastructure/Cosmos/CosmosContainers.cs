namespace Certigo.Infrastructure.Cosmos;

public static class CosmosContainers
{
    public const string DatabaseName = "certigo";
    public const string Users = "users";
    public const string Content = "content";
    public const string ContentPublic = "content-public";
    public const string ContentPrivate = "content-private";
    public const string ContentControl = "content-control";
    public const string Progress = "progress";
    public const string Attempts = "attempts";
    public const string Events = "events";
    public const string Leaderboard = "leaderboard";
    public const string Economy = "economy";
    public const string Friends = "friends";

    public static IReadOnlyList<CosmosContainerDefinition> All { get; } =
    [
        new(Users, "/id"),
        new(Content, "/trackId"),
        new(ContentPublic, "/releaseId"),
        new(ContentPrivate, "/releaseId"),
        new(ContentControl, "/scope"),
        new(Progress, "/userId"),
        new(Attempts, "/userId", DefaultTimeToLive: -1),
        new(Events, "/userId"),
        new(Leaderboard, "/periodLeagueId"),
        new(Economy, "/userId"),
        new(Friends, "/userId")
    ];
}

public sealed record CosmosContainerDefinition(
    string Name,
    string PartitionKeyPath,
    int? DefaultTimeToLive = null);
