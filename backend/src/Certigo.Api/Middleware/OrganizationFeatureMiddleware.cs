using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Middleware;

namespace Certigo.Api.Middleware;

public sealed class OrganizationFeatureMiddleware(OrganizationFeatureOptions options)
    : IFunctionsWorkerMiddleware
{
    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var request = await context.GetHttpRequestDataAsync();
        if (request is not null
            && IsOrganizationPath(request.Url.AbsolutePath)
            && !options.HttpSurfaceEnabled)
        {
            throw new OrganizationFeatureDisabledException();
        }

        await next(context);
    }

    private static bool IsOrganizationPath(string path) =>
        path.StartsWith("/api/v1/organizations", StringComparison.OrdinalIgnoreCase)
        || path.StartsWith(
            "/api/v1/organization-invitations",
            StringComparison.OrdinalIgnoreCase);
}
