using System.Net;
using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class EnterpriseIdentityFeatureTests
{
    [Theory]
    [InlineData("shadow")]
    [InlineData("read")]
    [InlineData("write")]
    [InlineData("enabled")]
    public void Configuration_rejects_every_mode_except_off(string value)
    {
        var action = () => EnterpriseIdentityFeatureOptions.Parse(value);

        action.Should().Throw<InvalidOperationException>();
    }

    [Theory]
    [InlineData("/api/v1/organizations/org-a/enterprise-identity/domains")]
    [InlineData("/api/v1/organizations/org-a/scim/v2/Users")]
    [InlineData("/api/v1/organizations/org-a/scim/v2/Groups")]
    [InlineData("/api/v1/enterprise-identity/metadata")]
    public async Task Disabled_surface_returns_404_before_authentication(string path)
    {
        var validator = FakeTokenValidator.Failing();
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        var feature = new EnterpriseIdentityFeatureMiddleware(
            EnterpriseIdentityFeatureOptions.Parse(null));
        var jwt = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: path);
        var handlerReached = false;

        await exception.Invoke(
            invocation.Context,
            context => feature.Invoke(
                context,
                inner => jwt.Invoke(inner, _ =>
                {
                    handlerReached = true;
                    return Task.CompletedTask;
                })));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.NotFound);
        validator.CallCount.Should().Be(0);
        handlerReached.Should().BeFalse();
    }

    [Fact]
    public async Task Function_guard_runs_before_request_body_is_read()
    {
        var options = EnterpriseIdentityFeatureOptions.Parse("off");
        var function = new EnterpriseIdentityFunctions(options);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/v1/organizations/org-a/scim/v2/Users",
            jsonBody: "{not-json");

        var action = () => function.Users(request, "org-a");

        await action.Should().ThrowAsync<EnterpriseIdentityFeatureDisabledException>();
    }
}
