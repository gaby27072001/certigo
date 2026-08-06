namespace Certigo.Infrastructure.Cosmos;

public static class CosmosContainers
{
    public const string DatabaseName = "certigo";
    public const string Users = "users";
    public const string Content = "content";
    public const string PublicContentReleases = "content-releases-public";
    public const string PrivateContentReleases = "content-releases-private";
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
        new(PublicContentReleases, "/partitionKey"),
        new(PrivateContentReleases, "/partitionKey"),
        new(Progress, "/userId"),
        new(Attempts, "/userId"),
        new(Events, "/userId"),
        new(Leaderboard, "/periodLeagueId"),
        new(Economy, "/userId"),
        new(Friends, "/userId")
    ];
}

public sealed record CosmosContainerDefinition(string Name, string PartitionKeyPath);
