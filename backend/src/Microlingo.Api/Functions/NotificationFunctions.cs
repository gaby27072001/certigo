using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

/// <summary>
/// Points d'entrée HTTP du moteur de notifications intelligentes : plan du jour
/// (quoi envoyer, à quelle heure locale, dans quel ordre) et gestion des
/// préférences de l'apprenant. Le serveur reste autoritaire : il borne les
/// réglages et planifie de façon déterministe.
/// </summary>
public sealed class NotificationFunctions(INotificationService notifications)
{
    [Function("GetNotificationPlan")]
    public async Task<HttpResponseData> GetNotificationPlan(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me/notifications/plan")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var plan = await notifications.GetPlanAsync(context.CancellationToken);
        return await request.JsonAsync(plan, cancellationToken: context.CancellationToken);
    }

    [Function("GetNotificationSettings")]
    public async Task<HttpResponseData> GetNotificationSettings(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me/notifications/settings")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var settings = await notifications.GetSettingsAsync(context.CancellationToken);
        return await request.JsonAsync(settings, cancellationToken: context.CancellationToken);
    }

    [Function("UpdateNotificationSettings")]
    public async Task<HttpResponseData> UpdateNotificationSettings(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "me/notifications/settings")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<UpdateNotificationSettingsRequest>(context.CancellationToken);
        var settings = await notifications.UpdateSettingsAsync(body, context.CancellationToken);
        return await request.JsonAsync(settings, cancellationToken: context.CancellationToken);
    }
}
