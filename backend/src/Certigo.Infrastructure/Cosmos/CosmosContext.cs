using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosContext(CosmosClient client, string? databaseName = null)
{
    private readonly Database _database = client.GetDatabase(string.IsNullOrWhiteSpace(databaseName)
        ? CosmosContainers.DatabaseName
        : databaseName);

    public Container Users => _database.GetContainer(CosmosContainers.Users);
    public Container Content => _database.GetContainer(CosmosContainers.Content);
    public Container PublicContentReleases =>
        _database.GetContainer(CosmosContainers.PublicContentReleases);
    public Container PrivateContentReleases =>
        _database.GetContainer(CosmosContainers.PrivateContentReleases);
    public Container Progress => _database.GetContainer(CosmosContainers.Progress);
    public Container Attempts => _database.GetContainer(CosmosContainers.Attempts);
    public Container Events => _database.GetContainer(CosmosContainers.Events);
    public Container Leaderboard => _database.GetContainer(CosmosContainers.Leaderboard);
    public Container Economy => _database.GetContainer(CosmosContainers.Economy);
    public Container Friends => _database.GetContainer(CosmosContainers.Friends);
}
