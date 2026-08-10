using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Certigo.Api.Http;

namespace Certigo.Api.Functions;

/// Anonymous liveness and readiness probes for platform and uptime monitoring.
public sealed class HealthFunctions(IHealthProbe probe, ILogger<HealthFunctions> logger)
{
    [Function("Health")]
    public async Task<HttpResponseData> Health(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequestData request,
        FunctionContext context)
        => await Ready(request, context);

    [Function("Readiness")]
    public async Task<HttpResponseData> Readiness(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health/ready")] HttpRequestData request,
        FunctionContext context)
        => await Ready(request, context);

    [Function("Liveness")]
    public async Task<HttpResponseData> Liveness(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health/live")] HttpRequestData request,
        FunctionContext context)
        => await request.JsonAsync(
            new { status = "healthy" },
            cancellationToken: context.CancellationToken);

    private async Task<HttpResponseData> Ready(HttpRequestData request, FunctionContext context)
    {
        var readiness = await probe.CheckAsync(context.CancellationToken);
        if (!readiness.IsHealthy)
        {
            logger.LogWarning(
                "Readiness failed. Cosmos={CosmosStatus}/{CosmosError}; Storage={StorageStatus}/{StorageError}; KeyVault={KeyVaultStatus}/{KeyVaultError}.",
                readiness.Cosmos.Status,
                readiness.Cosmos.ErrorCode,
                readiness.Storage.Status,
                readiness.Storage.ErrorCode,
                readiness.KeyVault.Status,
                readiness.KeyVault.ErrorCode);
        }

        return await request.JsonAsync(
            new
            {
                status = readiness.IsHealthy ? "healthy" : "unhealthy",
                checks = new
                {
                    cosmos = readiness.Cosmos,
                    storage = readiness.Storage,
                    keyVault = readiness.KeyVault
                }
            },
            readiness.IsHealthy ? HttpStatusCode.OK : HttpStatusCode.ServiceUnavailable,
            context.CancellationToken);
    }
}
