using System.Net;
using System.Text.Json;
using Certigo.Api.Observability;
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
            NullLogger<HealthFunctions>.Instance,
            KnownBuild());
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
            NullLogger<HealthFunctions>.Instance,
            KnownBuild());
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
        var function = new HealthFunctions(probe, NullLogger<HealthFunctions>.Instance, KnownBuild());
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/health/live");

        var response = await function.Liveness(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        probe.Calls.Should().Be(0);
        var payload = await response.ReadJsonAsync<JsonElement>();
        payload.EnumerateObject().Select(property => property.Name)
            .Should().BeEquivalentTo("status", "commitSha", "buildTimeUtc");
        payload.GetProperty("status").GetString().Should().Be("healthy");
        payload.GetProperty("commitSha").GetString().Should().Be("653e9112ff53");
        payload.GetProperty("buildTimeUtc").GetDateTimeOffset().Should().Be(KnownBuild().BuildTimeUtc);

        var secondResponse = await function.Liveness(request, context);
        (await secondResponse.ReadBodyAsStringAsync()).Should().Be(await response.ReadBodyAsStringAsync());
    }

    [Fact]
    public async Task Liveness_keeps_missing_identity_explicit_without_fabricating_values()
    {
        var function = new HealthFunctions(
            new CountingHealthProbe(),
            NullLogger<HealthFunctions>.Instance,
            new BuildIdentity(null, null));
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/health/live");

        var response = await function.Liveness(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var payload = await response.ReadJsonAsync<JsonElement>();
        payload.GetProperty("status").GetString().Should().Be("healthy");
        payload.GetProperty("commitSha").ValueKind.Should().Be(JsonValueKind.Null);
        payload.GetProperty("buildTimeUtc").ValueKind.Should().Be(JsonValueKind.Null);
    }

    private static BuildIdentity KnownBuild()
        => new("653e9112ff539bef3e937605cfc369216f2cb36f", "2026-09-25T10:15:30.1234567Z");

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
