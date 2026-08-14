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
        var function = new HealthFunctions(
            new StubHealthProbe(HealthyReadiness()),
            NullLogger<HealthFunctions>.Instance);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/health");

        var response = await function.Health(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var payload = await response.ReadJsonAsync<HealthResponse>();
        payload.Status.Should().Be("healthy");
        payload.Checks.Cosmos.Status.Should().Be("ok");
        payload.Checks.Storage.Status.Should().Be("ok");
        payload.Checks.KeyVault.Status.Should().Be("ok");
    }

    [Fact]
    public async Task Health_returns_service_unavailable_when_the_probe_throws()
    {
        var function = new HealthFunctions(
            new StubHealthProbe(new ReadinessHealth(
                new DependencyHealth("error", 12, "forbidden"),
                new DependencyHealth("ok", 8),
                new DependencyHealth("ok", 9))),
            NullLogger<HealthFunctions>.Instance);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/health");

        var response = await function.Health(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        var payload = await response.ReadJsonAsync<HealthResponse>();
        payload.Status.Should().Be("unhealthy");
        payload.Checks.Cosmos.Status.Should().Be("error");
        payload.Checks.Cosmos.ErrorCode.Should().Be("forbidden");
        payload.Checks.Storage.Status.Should().Be("ok");
        payload.Checks.KeyVault.Status.Should().Be("ok");
    }

    [Fact]
    public async Task Liveness_does_not_call_dependencies()
    {
        var probe = new CountingHealthProbe();
        var function = new HealthFunctions(probe, NullLogger<HealthFunctions>.Instance);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/health/live");

        var response = await function.Liveness(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        probe.Calls.Should().Be(0);
    }

    private static ReadinessHealth HealthyReadiness()
        => new(
            new DependencyHealth("ok", 1),
            new DependencyHealth("ok", 2),
            new DependencyHealth("ok", 3));

    private sealed class StubHealthProbe(ReadinessHealth result) : IHealthProbe
    {
        public Task<ReadinessHealth> CheckAsync(CancellationToken cancellationToken)
            => Task.FromResult(result);
    }

    private sealed class CountingHealthProbe : IHealthProbe
    {
        public int Calls { get; private set; }

        public Task<ReadinessHealth> CheckAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(HealthyReadiness());
        }
    }

    private sealed record HealthResponse(string Status, HealthChecks Checks);

    private sealed record HealthChecks(
        DependencyHealth Cosmos,
        DependencyHealth Storage,
        DependencyHealth KeyVault);
}
