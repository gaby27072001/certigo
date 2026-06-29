using Certigo.Infrastructure.Cosmos;

namespace Certigo.Api.Functions;

public interface IHealthProbe
{
    Task CheckAsync(CancellationToken cancellationToken);
}

internal sealed class CosmosHealthProbe(CosmosContext cosmos) : IHealthProbe
{
    public async Task CheckAsync(CancellationToken cancellationToken)
        => await cosmos.Users.ReadContainerAsync(cancellationToken: cancellationToken);
}
