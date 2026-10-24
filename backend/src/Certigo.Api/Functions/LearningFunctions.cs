using System.Globalization;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class LearningFunctions(IAttemptHistoryService history)
{
    [Function("GetMyAttemptHistory")]
    public async Task<HttpResponseData> GetMyHistory(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me/history")]
        HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var query = QueryHelpers.ParseQuery(request.Url.Query);
        if (query.Keys.Any(key => key is not ("limit" or "cursor"))
            || query.Values.Any(value => value.Count > 1))
        {
            throw new RequestValidationException("History query parameters are invalid.");
        }

        var limit = AttemptHistoryService.DefaultLimit;
        if (query.TryGetValue("limit", out var limitValue)
            && (!int.TryParse(
                    limitValue.ToString(),
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out limit)
                || limit is < 1 or > AttemptHistoryService.MaximumLimit))
        {
            throw new RequestValidationException("History limit is invalid.");
        }

        var cursor = query.TryGetValue("cursor", out var cursorValue)
            ? cursorValue.ToString()
            : null;
        var page = await history.GetPageAsync(limit, cursor, context.CancellationToken);
        var response = await request.JsonAsync(page, cancellationToken: context.CancellationToken);
        response.Headers.Add("Cache-Control", "no-store");
        return response;
    }
}
