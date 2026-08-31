using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Middleware;

namespace Certigo.Api.Middleware;

public sealed class EnterpriseIdentityFeatureMiddleware(EnterpriseIdentityFeatureOptions options)
    : IFunctionsWorkerMiddleware
{
    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var request = await context.GetHttpRequestDataAsync();
        if (request is not null
            && IsEnterpriseIdentityPath(request.Url.AbsolutePath)
            && options.Mode == EnterpriseIdentityFeatureMode.Off)
        {
            throw new EnterpriseIdentityFeatureDisabledException();
        }

        await next(context);
    }

    internal static bool IsEnterpriseIdentityPath(string path) =>
        path.Equals(
            "/api/v1/enterprise-identity/metadata",
            StringComparison.OrdinalIgnoreCase)
        || path.StartsWith(
            "/api/v1/organizations/",
            StringComparison.OrdinalIgnoreCase)
        && (path.Contains("/enterprise-identity", StringComparison.OrdinalIgnoreCase)
            || path.Contains("/scim/v2", StringComparison.OrdinalIgnoreCase));
}
