using System.Net;
using Microsoft.Azure.Cosmos;
using Microlingo.Application.Abstractions;

namespace Microlingo.Infrastructure.Cosmos;

/// Stores email/password credentials in the Users container, each in its own
/// partition (id = partition key = <c>credential::{emailLower}</c>). This reuses
/// the existing container — no new Cosmos container or Bicep change — while
/// staying isolated from profile documents (whose id is the userId).
public sealed class CosmosUserCredentialRepository(CosmosContext context) : IUserCredentialRepository
{
    public Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        var id = UserCredentialRecord.IdFor(Normalize(email));
        return context.Users.ReadOrDefaultAsync<UserCredentialRecord>(id, new PartitionKey(id), cancellationToken);
    }

    public async Task CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        try
        {
            await context.Users.CreateItemAsync(record, new PartitionKey(record.Id), cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            throw new DuplicateRecordException($"A credential for '{record.Email}' already exists.");
        }
    }

    private static string Normalize(string email) => (email ?? string.Empty).Trim().ToLowerInvariant();
}
