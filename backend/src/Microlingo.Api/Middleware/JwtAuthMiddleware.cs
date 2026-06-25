using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Microlingo.Api.Auth;
using Microlingo.Application.Abstractions;

namespace Microlingo.Api.Middleware;

public sealed class JwtAuthMiddleware(ITokenValidator tokenValidator) : IFunctionsWorkerMiddleware
{
    private static readonly HashSet<string> AnonymousPaths = new(StringComparer.OrdinalIgnoreCase)
    {
        "/api/health",
        "/api/auth/register",
        "/api/auth/login",
        "/api/auth/refresh"
    };

    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var request = await context.GetHttpRequestDataAsync();
        if (request is null || IsAnonymousPath(request))
        {
            await next(context);
            return;
        }

        var header = request.Headers.TryGetValues("Authorization", out var values)
            ? values.FirstOrDefault()
            : null;
        if (header is null || !header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            await Unauthorized(context, request);
            return;
        }

        var token = header["Bearer ".Length..].Trim();
        var validation = await tokenValidator.TryValidateAsync(token, context.CancellationToken);
        if (!validation.Succeeded || validation.Principal is null)
        {
            await Unauthorized(context, request);
            return;
        }

        context.Items["User"] = validation.Principal;
        FunctionUserContext.Current.Value = validation.Principal;
        try
        {
            await next(context);
        }
        finally
        {
            FunctionUserContext.Current.Value = null;
        }
    }

    private static async Task Unauthorized(FunctionContext context, HttpRequestData request)
    {
        var response = request.CreateResponse(HttpStatusCode.Unauthorized);
        await response.WriteStringAsync("Unauthorized", context.CancellationToken);
        context.GetInvocationResult().Value = response;
    }

    private static bool IsAnonymousPath(HttpRequestData request)
    {
        var path = request.Url.AbsolutePath;
        if (path.Length > 1)
        {
            path = path.TrimEnd('/');
        }

        return AnonymousPaths.Contains(path);
    }
}
