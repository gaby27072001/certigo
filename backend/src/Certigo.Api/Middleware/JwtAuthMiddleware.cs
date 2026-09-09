using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Certigo.Api.Auth;
using Certigo.Application.Abstractions;

namespace Certigo.Api.Middleware;

public sealed class JwtAuthMiddleware(
    ITokenValidator tokenValidator,
    IAccountDeletionAccessGuard? accountDeletionGuard = null,
    IReauthenticationProofValidator? reauthenticationProofValidator = null)
    : IFunctionsWorkerMiddleware
{
    private static readonly HashSet<string> AnonymousPaths = new(StringComparer.OrdinalIgnoreCase)
    {
        "/api/health",
        "/api/health/live",
        "/api/health/ready",
        "/api/auth/register",
        "/api/auth/login",
        "/api/auth/refresh",
        "/api/auth/verify-email",
        "/api/auth/resend-verification",
        "/api/auth/request-password-reset",
        "/api/auth/reset-password"
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

        var userId = validation.UserId
            ?? validation.Principal.FindFirst("oid")?.Value
            ?? validation.Principal.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? validation.Principal.FindFirst("sub")?.Value;
        if (string.IsNullOrWhiteSpace(userId))
        {
            await Unauthorized(context, request);
            return;
        }

        if (accountDeletionGuard is not null
            && !IsAccountDeletionPath(request)
            && await accountDeletionGuard.IsBlockedAsync(userId, context.CancellationToken))
        {
            await Locked(context, request);
            return;
        }

        if (IsAccountDeletionRequest(request)
            && request.Headers.TryGetValues("X-Certigo-Reauthentication", out var proofValues)
            && proofValues.FirstOrDefault() is { } proofToken
            && !string.IsNullOrWhiteSpace(proofToken))
        {
            var proof = await (reauthenticationProofValidator is null
                ? tokenValidator.TryValidateAsync(proofToken.Trim(), context.CancellationToken)
                : reauthenticationProofValidator.TryValidateAsync(
                    proofToken.Trim(),
                    context.CancellationToken));
            var proofUserId = proof.UserId
                ?? proof.Principal?.FindFirst("oid")?.Value
                ?? proof.Principal?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                ?? proof.Principal?.FindFirst("sub")?.Value;
            if (!proof.Succeeded
                || proof.Principal is null
                || !string.Equals(proofUserId, userId, StringComparison.Ordinal))
            {
                await Unauthorized(context, request);
                return;
            }

            context.Items["ReauthenticatedUser"] = proof.Principal;
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

    private static async Task Locked(FunctionContext context, HttpRequestData request)
    {
        var response = request.CreateResponse((HttpStatusCode)423);
        await response.WriteStringAsync(
            "Account deletion is in progress.",
            context.CancellationToken);
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

    private static bool IsAccountDeletionPath(HttpRequestData request)
    {
        var path = request.Url.AbsolutePath.TrimEnd('/');
        return path.Equals("/api/account/deletion", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsAccountDeletionRequest(HttpRequestData request) =>
        IsAccountDeletionPath(request)
        && request.Method.Equals("POST", StringComparison.OrdinalIgnoreCase);
}
