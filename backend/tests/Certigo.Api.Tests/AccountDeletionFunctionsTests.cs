using System.Net;
using System.Security.Claims;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class AccountDeletionFunctionsTests
{
    [Fact]
    public async Task Get_requires_authenticated_context_and_returns_status()
    {
        var service = new FakeAccountDeletionService();
        var function = new AccountDeletionFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/account/deletion");

        var response = await function.Get(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.GetCalls.Should().Be(1);
    }

    [Fact]
    public async Task Request_uses_the_server_validated_reauthentication_principal()
    {
        var service = new FakeAccountDeletionService
        {
            Result = new AccountDeletionDto(
                AccountDeletionStatus.Pending,
                2,
                5,
                DateTimeOffset.UtcNow),
        };
        var function = new AccountDeletionFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var proofInstant = DateTimeOffset.FromUnixTimeSeconds(
            DateTimeOffset.UtcNow.AddMinutes(-1).ToUnixTimeSeconds());
        context.Items["ReauthenticatedUser"] = new ClaimsPrincipal(
            new ClaimsIdentity(
                [
                    new Claim(ClaimTypes.NameIdentifier, "user-1"),
                    new Claim("auth_time", proofInstant.ToUnixTimeSeconds().ToString()),
                ],
                "proof"));
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/account/deletion");

        var response = await function.Request(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.Accepted);
        service.AuthenticatedAt.Should().Be(proofInstant);
    }

    [Fact]
    public async Task Request_returns_ok_only_after_server_confirmed_completion()
    {
        var service = new FakeAccountDeletionService
        {
            Result = new AccountDeletionDto(
                AccountDeletionStatus.Completed,
                5,
                5,
                DateTimeOffset.UtcNow.AddMinutes(-1),
                DateTimeOffset.UtcNow),
        };
        var function = new AccountDeletionFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/account/deletion");

        var response = await function.Request(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    private sealed class FakeAccountDeletionService : IAccountDeletionService
    {
        public AccountDeletionDto Result { get; init; } =
            new(AccountDeletionStatus.NotRequested, 0, 5);

        public int GetCalls { get; private set; }
        public DateTimeOffset? AuthenticatedAt { get; private set; }

        public Task<AccountDeletionDto> GetStatusAsync(
            CancellationToken cancellationToken = default)
        {
            GetCalls++;
            return Task.FromResult(Result);
        }

        public Task<AccountDeletionDto> RequestAsync(
            DateTimeOffset? authenticatedAt,
            CancellationToken cancellationToken = default)
        {
            AuthenticatedAt = authenticatedAt;
            return Task.FromResult(Result);
        }
    }
}
