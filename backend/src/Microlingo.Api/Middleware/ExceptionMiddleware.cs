using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Microsoft.Extensions.Logging;
using Microlingo.Api.Http;

namespace Microlingo.Api.Middleware;

public sealed class ExceptionMiddleware(ILogger<ExceptionMiddleware> logger) : IFunctionsWorkerMiddleware
{
    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception in function {FunctionName}.", context.FunctionDefinition.Name);
            var request = await context.GetHttpRequestDataAsync();
            if (request is null)
            {
                throw;
            }

            var response = request.CreateResponse(HttpStatusCode.InternalServerError);
            await response.JsonAsync(new ProblemDetails
            {
                Title = "Unexpected server error",
                Detail = "Microlingo could not complete the request.",
                Status = (int)HttpStatusCode.InternalServerError
            }, context.CancellationToken);
            context.GetInvocationResult().Value = response;
        }
    }
}
