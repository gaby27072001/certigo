using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;
using Microsoft.Extensions.Logging.Abstractions;

namespace Certigo.Api.Tests;

public sealed class OrganizationFunctionsTests
{
    [Theory]
    [InlineData("off")]
    [InlineData("shadow")]
    public async Task Disabled_surface_returns_before_authentication_or_service_access(string mode)
    {
        var service = new FakeOrganizationService();
        var function = new OrganizationFunctions(
            OrganizationFeatureOptions.Parse(mode),
            service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/v1/organizations",
            new CreateOrganizationRequest("Contoso"));

        var action = () => function.Create(request, context);

        await action.Should().ThrowAsync<OrganizationFeatureDisabledException>();
        service.CallCount.Should().Be(0);
    }

    [Theory]
    [InlineData("off")]
    [InlineData("shadow")]
    public async Task Disabled_surface_is_hidden_before_jwt_authentication(string mode)
    {
        var validator = FakeTokenValidator.Failing();
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        var feature = new OrganizationFeatureMiddleware(
            OrganizationFeatureOptions.Parse(mode));
        var jwt = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: "/api/v1/organizations");

        await exception.Invoke(
            invocation.Context,
            context => feature.Invoke(
                context,
                inner => jwt.Invoke(inner, _ => Task.CompletedTask)));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(System.Net.HttpStatusCode.NotFound);
        validator.CallCount.Should().Be(0);
    }

    private sealed class FakeOrganizationService : IOrganizationService
    {
        public int CallCount { get; private set; }

        public Task<OrganizationDto> CreateAsync(
            string name,
            string idempotencyKey,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<OrganizationDto> GetAsync(
            string organizationId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<OrganizationInvitationDto> InviteAsync(
            string organizationId,
            string recipientEmail,
            OrganizationRole role,
            string idempotencyKey,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<OrganizationMembershipDto> AcceptInvitationAsync(
            string organizationId,
            string invitationId,
            string token,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<OrganizationTeamDto> CreateTeamAsync(
            string organizationId,
            string name,
            string idempotencyKey,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task AddTeamMemberAsync(
            string organizationId,
            string teamId,
            string personId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }

        public Task<OrganizationOffboardingDto> OffboardAsync(
            string organizationId,
            string personId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            throw new NotSupportedException();
        }
    }
}
