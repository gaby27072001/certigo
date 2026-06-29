using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Certigo.Api.Http;
using Certigo.Infrastructure.Cosmos;

namespace Certigo.Api.Functions;

/// Liveness/readiness probe. Anonymous (allow-listed in JwtAuthMiddleware) so an
/// orchestrator or uptime monitor can poll it without a token. It confirms the API
/// can reach Cosmos with its managed identity — the dependency most likely to break
/// (mis-scoped RBAC, network egress, or a wrong endpoint).
public sealed class HealthFunctions(IHealthProbe probe, ILogger<HealthFunctions> logger)
{
    [Function("Health")]
    public async Task<HttpResponseData> Health(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequestData request,
        FunctionContext context)
    {
        try
        {
            await probe.CheckAsync(context.CancellationToken);
            return await request.JsonAsync(
                new { status = "healthy", checks = new { cosmos = "ok" } },
                cancellationToken: context.CancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Readiness check failed: Cosmos unreachable.");
            return await request.JsonAsync(
                new { status = "unhealthy", checks = new { cosmos = "error" } },
                HttpStatusCode.ServiceUnavailable,
                context.CancellationToken);
        }
    }
}
