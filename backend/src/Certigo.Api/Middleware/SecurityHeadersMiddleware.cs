using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;

namespace Certigo.Api.Middleware;

/// Stamps a small, fixed set of defensive security headers onto every HTTP response.
/// Registered first (outermost) in the worker pipeline so it also covers the error
/// and 401 responses produced by the inner middleware and the anonymous /health
/// endpoint. Non-HTTP triggers (timers/queues) carry no response and are a no-op.
/// An existing header is never overwritten, so a handler that sets its own value wins
/// and no header is duplicated.
public sealed class SecurityHeadersMiddleware : IFunctionsWorkerMiddleware
{
    // This is an HTTPS-served API for a mobile client: X-Content-Type-Options and
    // Strict-Transport-Security are the load-bearing headers; X-Frame-Options and
    // Referrer-Policy are inexpensive, harmless hardening.
    private static readonly (string Name, string Value)[] Headers =
    {
        ("X-Content-Type-Options", "nosniff"),
        ("Strict-Transport-Security", "max-age=63072000; includeSubDomains"),
        ("X-Frame-Options", "DENY"),
        ("Referrer-Policy", "no-referrer"),
    };

    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        await next(context);

        // Only HTTP invocations produce a response to stamp; other trigger types are skipped.
        var response = context.GetHttpResponseData();
        if (response is null)
        {
            return;
        }

        foreach (var (name, value) in Headers)
        {
            if (!response.Headers.Contains(name))
            {
                response.Headers.Add(name, value);
            }
        }
    }
}
