using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class VivaLearningFunctions(
    VivaLearningFeatureOptions options,
    IVivaLearningService vivaLearning)
{
    [Function("GetVivaLearningProviderV1")]
    public async Task<HttpResponseData> GetProvider(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "v1/organizations/{organizationId}/integrations/viva-learning/provider")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var provider = await vivaLearning.GetProviderAsync(
            organizationId,
            context.CancellationToken);
        return await request.JsonAsync(provider, cancellationToken: context.CancellationToken);
    }

    [Function("GetVivaLearningContentV1")]
    public async Task<HttpResponseData> GetLearningContent(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "v1/organizations/{organizationId}/integrations/viva-learning/learning-content")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var content = await vivaLearning.GetLearningContentAsync(
            organizationId,
            context.CancellationToken);
        return await request.JsonAsync(content, cancellationToken: context.CancellationToken);
    }

    private void EnsureAvailable()
    {
        if (options.Mode == VivaLearningFeatureMode.Off)
        {
            throw new VivaLearningFeatureDisabledException();
        }
    }
}
