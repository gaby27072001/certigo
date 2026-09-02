using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class EnterpriseLearningMetricsFunctions(
    EnterpriseLearningMetricsFeatureOptions options,
    IEnterpriseLearningMetricsService metrics)
{
    [Function("StartEnterpriseLearningSessionV1")]
    public async Task<HttpResponseData> StartSession(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/learning-metrics/sessions")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var result = await metrics.StartSessionAsync(
            organizationId,
            context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("RecordEnterpriseLearningHeartbeatV1")]
    public async Task<HttpResponseData> RecordHeartbeat(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/learning-metrics/heartbeats")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var body = await request.ReadJsonAsync<EnterpriseLearningHeartbeatRequest>(
            context.CancellationToken);
        var result = await metrics.RecordHeartbeatAsync(
            organizationId,
            body,
            context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("GetEnterpriseLearningDailySummaryV1")]
    public async Task<HttpResponseData> GetDailySummary(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "v1/organizations/{organizationId}/learning-metrics/daily/{day}")]
        HttpRequestData request,
        string organizationId,
        string day,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        if (!DateOnly.TryParseExact(day, "yyyy-MM-dd", out var parsedDay))
        {
            throw new BadRequestException("Summary day must use yyyy-MM-dd.");
        }
        var result = await metrics.GetDailySummaryAsync(
            organizationId,
            parsedDay,
            context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("GetEnterpriseLearningActiveSummaryV1")]
    public async Task<HttpResponseData> GetActiveSummary(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "v1/organizations/{organizationId}/learning-metrics/active")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var result = await metrics.GetActiveSummaryAsync(
            organizationId,
            context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    private void EnsureAvailable()
    {
        if (options.Mode == EnterpriseLearningMetricsFeatureMode.Off)
        {
            throw new EnterpriseLearningMetricsFeatureDisabledException();
        }
    }
}
