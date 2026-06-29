using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class CatalogFunctions(IContentService content)
{
    [Function("GetCatalog")]
    public async Task<HttpResponseData> GetCatalog(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "catalog/tracks")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var catalog = await content.GetCatalogAsync(context.CancellationToken);
        return await request.JsonAsync(catalog, cancellationToken: context.CancellationToken);
    }
}
