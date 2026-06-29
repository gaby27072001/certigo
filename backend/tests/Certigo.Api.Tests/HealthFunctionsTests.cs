using System.Net;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Certigo.Api.Functions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class HealthFunctionsTests
{
    [Fact]
    public async Task Health_returns_healthy_payload_when_the_probe_succeeds()
    {
        var function = new HealthFunctions(new StubHealthProbe(), NullLogger<HealthFunctions>.Instance);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/health");

        var response = await function.Health(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var payload = await response.ReadJsonAsync<HealthResponse>();
        payload.Status.Should().Be("healthy");
        payload.Checks.Cosmos.Should().Be("ok");
    }

    [Fact]
    public async Task Health_returns_service_unavailable_when_the_probe_throws()
    {
        var function = new HealthFunctions(
            new StubHealthProbe(new InvalidOperationException("Cosmos unavailable")),
            NullLogger<HealthFunctions>.Instance);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/health");

        var response = await function.Health(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        var payload = await response.ReadJsonAsync<HealthResponse>();
        payload.Status.Should().Be("unhealthy");
        payload.Checks.Cosmos.Should().Be("error");
    }

    private sealed class StubHealthProbe(Exception? failure = null) : IHealthProbe
    {
        public Task CheckAsync(CancellationToken cancellationToken)
            => failure is null ? Task.CompletedTask : Task.FromException(failure);
    }

    private sealed record HealthResponse(string Status, HealthChecks Checks);

    private sealed record HealthChecks(string Cosmos);
}
