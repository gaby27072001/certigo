using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Middleware;

namespace Certigo.Api.Middleware;

public sealed class EnterpriseLearningMetricsFeatureMiddleware(
    EnterpriseLearningMetricsFeatureOptions options) : IFunctionsWorkerMiddleware
{
    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var request = await context.GetHttpRequestDataAsync();
        if (request is not null
            && request.Url.AbsolutePath.Contains(
                "/learning-metrics",
                StringComparison.OrdinalIgnoreCase)
            && options.Mode == EnterpriseLearningMetricsFeatureMode.Off)
        {
            throw new EnterpriseLearningMetricsFeatureDisabledException();
        }
        await next(context);
    }
}
