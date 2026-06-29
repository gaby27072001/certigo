using System.Collections.Concurrent;
using System.Net;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Certigo.Api.Middleware;

/// <summary>
/// Sliding-window rate limiter that caps authenticated requests to
/// <c>RATE_LIMIT_RPM</c> calls per minute per userId (default: 60).
/// Disabled unless <c>RATE_LIMIT_ENABLED=true</c>.
/// Exempt paths (e.g. <c>/api/health</c>) bypass the check entirely.
/// Returns HTTP 429 with a <c>Retry-After: 60</c> header when the window is full.
/// </summary>
public sealed class RateLimitMiddleware : IFunctionsWorkerMiddleware
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private static readonly HashSet<string> ExemptPaths = new(StringComparer.OrdinalIgnoreCase)
    {
        "/api/health"
    };

    private readonly ConcurrentDictionary<string, WindowState> _windows = new(StringComparer.Ordinal);
    private readonly bool _enabled;
    private readonly int _limitRpm;
    private readonly ILogger<RateLimitMiddleware> _logger;

    public RateLimitMiddleware(IConfiguration configuration, ILogger<RateLimitMiddleware> logger)
    {
        _logger = logger;
        _enabled = string.Equals(
            configuration["RATE_LIMIT_ENABLED"], "true", StringComparison.OrdinalIgnoreCase);

        _limitRpm = int.TryParse(configuration["RATE_LIMIT_RPM"], out var rpm) && rpm > 0
            ? rpm
            : 60;
    }

    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        if (!_enabled)
        {
            await next(context);
            return;
        }

        var request = await context.GetHttpRequestDataAsync();
        if (request is null || IsExemptPath(request))
        {
            await next(context);
            return;
        }

        var userId = GetUserId(context);
        if (userId is null)
        {
            // Unauthenticated request — rate limiting is user-scoped, skip.
            await next(context);
            return;
        }

        if (IsLimitExceeded(userId))
        {
            _logger.LogWarning(
                "Rate limit exceeded for user {UserId} in function {FunctionName}.",
                userId,
                context.FunctionDefinition.Name);

            var correlationId = context.Items.TryGetValue("CorrelationId", out var cid) ? cid as string : null;

            var response = request.CreateResponse(HttpStatusCode.TooManyRequests);
            response.Headers.Add("Retry-After", "60");
            response.Headers.Add("Content-Type", "application/problem+json");
            var problem = new
            {
                title = "Too Many Requests",
                detail = "You have exceeded the allowed request rate. Please retry after 60 seconds.",
                status = 429,
                correlationId
            };
            await response.WriteStringAsync(JsonSerializer.Serialize(problem, JsonOptions), context.CancellationToken);
            context.GetInvocationResult().Value = response;
            return;
        }

        await next(context);
    }

    private bool IsLimitExceeded(string userId)
    {
        var now = DateTimeOffset.UtcNow;
        var windowStart = now.AddMinutes(-1);

        _windows.AddOrUpdate(
            userId,
            _ => new WindowState(now, 1),
            (_, existing) =>
            {
                // Reset window if it has expired.
                if (existing.WindowStart < windowStart)
                {
                    return new WindowState(now, 1);
                }

                return existing with { Count = existing.Count + 1 };
            });

        return _windows.TryGetValue(userId, out var state) && state.Count > _limitRpm;
    }

    private static bool IsExemptPath(HttpRequestData request)
    {
        var path = request.Url.AbsolutePath;
        if (path.Length > 1)
        {
            path = path.TrimEnd('/');
        }

        return ExemptPaths.Contains(path);
    }

    private static string? GetUserId(FunctionContext context)
    {
        if (!context.Items.TryGetValue("User", out var userObj)
            || userObj is not System.Security.Claims.ClaimsPrincipal principal)
        {
            return null;
        }

        return principal.FindFirst("oid")?.Value
            ?? principal.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? principal.FindFirst("sub")?.Value;
    }

    private sealed record WindowState(DateTimeOffset WindowStart, int Count);
}
