using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

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
