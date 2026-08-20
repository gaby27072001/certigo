using System.Globalization;
using System.Net;
using System.Security.Claims;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class AccountDeletionFunctions(IAccountDeletionService deletion)
{
    [Function("GetAccountDeletion")]
    public async Task<HttpResponseData> Get(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "account/deletion")]
        HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var status = await deletion.GetStatusAsync(context.CancellationToken);
        return await request.JsonAsync(status, cancellationToken: context.CancellationToken);
    }

    [Function("RequestAccountDeletion")]
    public async Task<HttpResponseData> Request(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "account/deletion")]
        HttpRequestData request,
        FunctionContext context)
    {
        var principal = context.Items.TryGetValue(
                "ReauthenticatedUser",
                out var reauthenticated)
            && reauthenticated is ClaimsPrincipal proof
                ? proof
                : context.GetUser();
        var status = await deletion.RequestAsync(
            AuthenticationInstant(principal),
            context.CancellationToken);
        return await request.JsonAsync(
            status,
            status.Status == AccountDeletionStatus.Completed
                ? HttpStatusCode.OK
                : HttpStatusCode.Accepted,
            context.CancellationToken);
    }

    internal static DateTimeOffset? AuthenticationInstant(ClaimsPrincipal principal)
    {
        var raw = principal.FindFirst("auth_time")?.Value;
        return long.TryParse(
            raw,
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out var seconds)
            ? DateTimeOffset.FromUnixTimeSeconds(seconds)
            : null;
    }
}
