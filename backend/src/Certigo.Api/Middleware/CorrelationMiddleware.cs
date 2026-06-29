using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Microsoft.Extensions.Logging;

namespace Certigo.Api.Middleware;

/// Provides the correlation id for the current invocation.
public interface ICorrelationContext
{
    string CorrelationId { get; }
}

/// Mutable implementation set by <see cref="CorrelationMiddleware"/> at the start of each request.
internal sealed class CorrelationContext : ICorrelationContext
{
    public string CorrelationId { get; set; } = string.Empty;
}

/// Reads or generates a <c>X-Correlation-Id</c>, stamps it on the logger scope,
/// exposes it via <see cref="ICorrelationContext"/>, and echoes it back on every
/// HTTP response (both success and error paths).
public sealed class CorrelationMiddleware(ILogger<CorrelationMiddleware> logger) : IFunctionsWorkerMiddleware
{
    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var request = await context.GetHttpRequestDataAsync();
        var correlationId = ResolveCorrelationId(request);

        // Expose for ExceptionMiddleware and any downstream code reading context.Items.
        context.Items["CorrelationId"] = correlationId;

        // Expose via the scoped service for handlers that inject ICorrelationContext.
        if (context.InstanceServices.GetService(typeof(ICorrelationContext)) is CorrelationContext mutable)
        {
            mutable.CorrelationId = correlationId;
        }

        using (logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = correlationId }))
        {
            await next(context);
        }

        // Stamp the header on the response for success paths.
        // Error paths are already stamped by ExceptionMiddleware.WriteProblemAsync.
        if (context.GetInvocationResult().Value is HttpResponseData response
            && !response.Headers.TryGetValues("x-correlation-id", out _))
        {
            response.Headers.Add("x-correlation-id", correlationId);
        }
    }

    private static string ResolveCorrelationId(HttpRequestData? request)
    {
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
}
