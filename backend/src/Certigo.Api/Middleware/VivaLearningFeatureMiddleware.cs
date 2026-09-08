using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Middleware;

namespace Certigo.Api.Middleware;

public sealed class VivaLearningFeatureMiddleware(VivaLearningFeatureOptions options)
    : IFunctionsWorkerMiddleware
{
    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var request = await context.GetHttpRequestDataAsync();
        if (request is not null
            && request.Url.AbsolutePath.Contains(
                "/integrations/viva-learning",
                StringComparison.OrdinalIgnoreCase)
            && options.Mode == VivaLearningFeatureMode.Off)
        {
            throw new VivaLearningFeatureDisabledException();
        }

        await next(context);
    }
}
