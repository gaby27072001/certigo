namespace Microlingo.Infrastructure.Cosmos;

public static class CosmosContainers
{
    public const string DatabaseName = "microlingo";
    public const string Users = "users";
    public const string Content = "content";
    public const string Progress = "progress";
    public const string Attempts = "attempts";
    public const string Events = "events";
    public const string Leaderboard = "leaderboard";

    public static IReadOnlyList<CosmosContainerDefinition> All { get; } =
    [
        new(Users, "/id"),
        new(Content, "/trackId"),
        new(Progress, "/userId"),
        new(Attempts, "/userId"),
        new(Events, "/userId"),
        new(Leaderboard, "/periodLeagueId")
    ];
}

public sealed record CosmosContainerDefinition(string Name, string PartitionKeyPath);
