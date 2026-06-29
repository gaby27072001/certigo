using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Microsoft.Extensions.Logging;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;

namespace Certigo.Api.Middleware;

public sealed class ExceptionMiddleware(ILogger<ExceptionMiddleware> logger) : IFunctionsWorkerMiddleware
{
    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        // Correlation id: honour an inbound x-correlation-id (so a request can be
        // traced end-to-end) or mint one. Pushed into the log scope and returned on
        // every error response so an incident can be pinned to exact log lines.
        var correlationId = await ResolveCorrelationIdAsync(context);
        context.Items["CorrelationId"] = correlationId;
        using var scope = logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = correlationId });

        try
        {
            await next(context);
        }
        catch (BadRequestException ex)
        {
            await WriteProblemAsync(context, HttpStatusCode.BadRequest, "Invalid request", ex.Message, correlationId);
        }
        catch (JsonException ex)
        {
            // Malformed JSON in request body is always a client error (400),
            // not a server fault — log at debug to avoid noise.
            logger.LogDebug(ex, "JSON deserialization failed in function {FunctionName}.", context.FunctionDefinition.Name);
            await WriteProblemAsync(context, HttpStatusCode.BadRequest, "Invalid request",
                $"Invalid JSON request body: {ex.Message}", correlationId);
        }
        catch (FormatException ex)
        {
            // Bad route/query parameter format (e.g. non-GUID id) is a client error.
            logger.LogDebug(ex, "Format error in function {FunctionName}.", context.FunctionDefinition.Name);
            await WriteProblemAsync(context, HttpStatusCode.BadRequest, "Invalid request", ex.Message, correlationId);
        }
        catch (AuthFailedException ex)
        {
            // Authentication failures (wrong credentials, expired refresh token).
            // Logged at information level — these are expected, not faults.
            logger.LogInformation("Authentication failed in function {FunctionName}.", context.FunctionDefinition.Name);
            await WriteProblemAsync(context, HttpStatusCode.Unauthorized, "Unauthorized", ex.Message, correlationId);
        }
        catch (RateLimitedException ex)
        {
            logger.LogWarning("Rate limit hit in function {FunctionName}.", context.FunctionDefinition.Name);
            await WriteProblemAsync(context, HttpStatusCode.TooManyRequests, "Too Many Requests", ex.Message, correlationId);
        }
        catch (DuplicateRecordException ex)
        {
            await WriteProblemAsync(context, HttpStatusCode.Conflict, "Conflict", ex.Message, correlationId);
        }
        catch (ConcurrencyConflictException ex)
        {
            logger.LogWarning(ex, "Concurrency conflict in function {FunctionName}.", context.FunctionDefinition.Name);
            await WriteProblemAsync(context, HttpStatusCode.Conflict, "Conflict",
                "The request conflicted with a concurrent update; please retry.", correlationId);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception in function {FunctionName}.", context.FunctionDefinition.Name);
            if (!await WriteProblemAsync(context, HttpStatusCode.InternalServerError, "Unexpected server error",
                    "Certigo could not complete the request.", correlationId))
            {
                throw;
            }
        }
    }

    private static async Task<string> ResolveCorrelationIdAsync(FunctionContext context)
    {
        // Fast path: CorrelationMiddleware already resolved and stored the id.
        if (context.Items.TryGetValue("CorrelationId", out var cached)
            && cached is string cachedId
            && !string.IsNullOrWhiteSpace(cachedId))
        {
            return cachedId;
        }

        // Fallback: resolve from the HTTP request (e.g. when ExceptionMiddleware is
        // invoked directly in tests without CorrelationMiddleware in the pipeline).
        var request = await context.GetHttpRequestDataAsync();
        if (request is not null
            && request.Headers.TryGetValues("x-correlation-id", out var values))
        {
            var inbound = values.FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(inbound))
            {
                return inbound;
            }
        }

        return Guid.NewGuid().ToString("n");
    }

    private static async Task<bool> WriteProblemAsync(
        FunctionContext context,
        HttpStatusCode status,
        string title,
        string detail,
        string correlationId)
    {
        var request = await context.GetHttpRequestDataAsync();
        if (request is null)
        {
            return false; // non-HTTP trigger: let the caller rethrow.
        }

        var response = request.CreateResponse(status);
        response.Headers.Add("x-correlation-id", correlationId);
        await response.JsonAsync(new ProblemDetails
        {
            Title = title,
            Detail = detail,
            Status = (int)status,
            Extensions = { ["correlationId"] = correlationId }
        }, context.CancellationToken);
        context.GetInvocationResult().Value = response;
        return true;
    }
}
