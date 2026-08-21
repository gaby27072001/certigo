using System.Net;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;

namespace Certigo.Api.Middleware;

public sealed class PortableAchievementFeatureMiddleware(PortableAchievementOptions options)
    : IFunctionsWorkerMiddleware
{
    private const string PersonalPrefix = "/api/me/portable-achievements";
    private const string VerificationPrefix = "/api/portable-achievements";

    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var request = await context.GetHttpRequestDataAsync();
        if (request is null || options.Enabled || !IsPortableAchievementPath(request.Url.AbsolutePath))
        {
            await next(context);
            return;
        }

        var response = request.CreateResponse(HttpStatusCode.NotFound);
        await response.WriteStringAsync("Not Found", context.CancellationToken);
        context.GetInvocationResult().Value = response;
    }

    private static bool IsPortableAchievementPath(string path) =>
        IsPathOrChild(path, PersonalPrefix) || IsPathOrChild(path, VerificationPrefix);

    private static bool IsPathOrChild(string path, string prefix) =>
        string.Equals(path.TrimEnd('/'), prefix, StringComparison.OrdinalIgnoreCase)
        || path.StartsWith($"{prefix}/", StringComparison.OrdinalIgnoreCase);
}
