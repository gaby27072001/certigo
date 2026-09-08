using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class VivaLearningFunctionsTests
{
    [Fact]
    public async Task Disabled_surface_returns_before_authentication_or_service_access()
    {
        var service = new FakeVivaLearningService();
        var function = new VivaLearningFunctions(
            VivaLearningFeatureOptions.Parse(null, null),
            service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/v1/organizations/organization-a/integrations/viva-learning/provider");

        var action = () => function.GetProvider(request, "organization-a", context);

        await action.Should().ThrowAsync<VivaLearningFeatureDisabledException>();
        service.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task Disabled_surface_is_hidden_before_jwt_authentication()
    {
        var validator = FakeTokenValidator.Failing();
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        var feature = new VivaLearningFeatureMiddleware(
            VivaLearningFeatureOptions.Parse(null, null));
        var jwt = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "GET",
            path: "/api/v1/organizations/organization-a/integrations/viva-learning/provider");

        await exception.Invoke(
            invocation.Context,
            context => feature.Invoke(
                context,
                inner => jwt.Invoke(inner, _ => Task.CompletedTask)));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(System.Net.HttpStatusCode.NotFound);
        validator.CallCount.Should().Be(0);
    }

    private sealed class FakeVivaLearningService : IVivaLearningService
    {
        public int CallCount { get; private set; }

        public Task<VivaLearningProviderDto> GetProviderAsync(
            string organizationId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<IReadOnlyList<VivaLearningContentDto>> GetLearningContentAsync(
            string organizationId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }
    }
}
