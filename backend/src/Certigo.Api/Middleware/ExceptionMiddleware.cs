using System.Net;
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
        catch (RequestValidationException ex)
        {
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
        catch (ContentAccessForbiddenException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.Forbidden,
                "Forbidden",
                ex.Message,
                correlationId);
        }
        catch (ContentReleasePreconditionRequiredException ex)
        {
            await WriteProblemAsync(
                context,
                (HttpStatusCode)428,
                "Precondition required",
                ex.Message,
                correlationId);
        }
        catch (ContentReleasePreconditionException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.PreconditionFailed,
                "Precondition failed",
                ex.Message,
                correlationId);
        }
        catch (ContentReleaseValidationException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.UnprocessableEntity,
                "Invalid content release",
                ex.Message,
                correlationId);
        }
        catch (ContentReleaseNotFoundException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.NotFound,
                "Content release not found",
                ex.Message,
                correlationId);
        }
        catch (ContentReleaseStateException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.Conflict,
                "Content release conflict",
                ex.Message,
                correlationId);
        }
        catch (ContentUnavailableException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.ServiceUnavailable,
                "Content unavailable",
                ex.Message,
                correlationId);
        }
        catch (PortableAchievementsDisabledException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.NotFound,
                "Feature unavailable",
                ex.Message,
                correlationId);
        }
        catch (PortableAchievementNotFoundException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.NotFound,
                "Portable achievement not found",
                ex.Message,
                correlationId);
        }
        catch (PortableAchievementConflictException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.Conflict,
                "Portable achievement conflict",
                ex.Message,
                correlationId);
        }
        catch (EmptyCatalogException)
        {
            logger.LogWarning(
                "Catalog empty in function {FunctionName} — database may not be seeded.",
                context.FunctionDefinition.Name);
            await WriteProblemAsync(context, HttpStatusCode.ServiceUnavailable, "Catalog unavailable",
                "No certification tracks are available yet. The database needs to be seeded.", correlationId);
        }
        catch (TrackNotFoundException ex)
        {
            await WriteProblemAsync(context, HttpStatusCode.NotFound, "Track not found", ex.Message, correlationId);
        }
        catch (ActiveTrackRequiredException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.Conflict,
                "Active track required",
                ex.Message,
                correlationId);
        }
        catch (ActiveTrackConflictException ex)
        {
            await WriteProblemAsync(
                context,
                HttpStatusCode.Conflict,
                "Active track conflict",
                ex.Message,
                correlationId);
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
