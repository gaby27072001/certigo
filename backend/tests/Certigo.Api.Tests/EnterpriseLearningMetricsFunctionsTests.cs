using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class EnterpriseLearningMetricsFunctionsTests
{
    [Fact]
    public async Task Disabled_surface_returns_before_authentication_or_service_access()
    {
        var service = new FakeMetricsService();
        var function = new EnterpriseLearningMetricsFunctions(
            EnterpriseLearningMetricsFeatureOptions.Parse(null),
            service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/v1/organizations/org-a/learning-metrics/heartbeats",
            new EnterpriseLearningHeartbeatRequest(
                "server-session-0000000000000001",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "offline-operation-0001",
                1,
                DateTimeOffset.UtcNow));

        var action = () => function.RecordHeartbeat(request, "org-a", context);

        await action.Should().ThrowAsync<EnterpriseLearningMetricsFeatureDisabledException>();
        service.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task Disabled_surface_is_hidden_before_jwt_authentication()
    {
        var validator = FakeTokenValidator.Failing();
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        var feature = new EnterpriseLearningMetricsFeatureMiddleware(
            EnterpriseLearningMetricsFeatureOptions.Parse(null));
        var jwt = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: "/api/v1/organizations/org-a/learning-metrics/heartbeats");

        await exception.Invoke(
            invocation.Context,
            context => feature.Invoke(
                context,
                inner => jwt.Invoke(inner, _ => Task.CompletedTask)));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(System.Net.HttpStatusCode.NotFound);
        validator.CallCount.Should().Be(0);
    }

    private sealed class FakeMetricsService : IEnterpriseLearningMetricsService
    {
        public int CallCount { get; private set; }

        public Task<EnterpriseLearningSessionDto> StartSessionAsync(
            string organizationId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<EnterpriseLearningHeartbeatDto> RecordHeartbeatAsync(
            string organizationId,
            EnterpriseLearningHeartbeatRequest request,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<EnterpriseLearningDailySummaryDto> GetDailySummaryAsync(
            string organizationId,
            DateOnly day,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<EnterpriseLearningActiveSummaryDto> GetActiveSummaryAsync(
            string organizationId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }
    }
}
