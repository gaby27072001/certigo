using System.Net;
using System.Text;
using Azure.Core;
using Certigo.Api.Auth;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class KeyVaultSecretValueResolverTests
{
    [Fact]
    public async Task Versioned_secret_uri_is_resolved_without_exposing_the_value()
    {
        var credential = new StubCredential();
        HttpRequestMessage? capturedRequest = null;
        using var httpClient = new HttpClient(new StubHandler(request =>
        {
            capturedRequest = request;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"value":"resolved-signing-secret"}""",
                    Encoding.UTF8,
                    "application/json")
            };
        }));

        var result = await KeyVaultSecretValueResolver.ResolveAsync(
            new Uri("https://kv-test.vault.azure.net/secrets/AUTH-JWT-SIGNING-KEY/version-1"),
            credential,
            httpClient,
            CancellationToken.None);

        result.Should().Be("resolved-signing-secret");
        credential.RequestedScopes.Should().Equal("https://vault.azure.net/.default");
        capturedRequest.Should().NotBeNull();
        capturedRequest!.RequestUri.Should().Be(
            "https://kv-test.vault.azure.net/secrets/AUTH-JWT-SIGNING-KEY/version-1?api-version=7.4");
        capturedRequest.Headers.Authorization!.Scheme.Should().Be("Bearer");
        capturedRequest.Headers.Authorization.Parameter.Should().Be("test-token");
    }

    [Fact]
    public async Task Non_key_vault_uri_is_rejected_before_any_request()
    {
        using var httpClient = new HttpClient(new StubHandler(
            _ => throw new InvalidOperationException("HTTP should not be called.")));

        var act = () => KeyVaultSecretValueResolver.ResolveAsync(
            new Uri("https://example.com/secrets/key/version"),
            new StubCredential(),
            httpClient,
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*versioned Azure Key Vault secret URI*");
    }

    [Fact]
    public async Task Failed_request_does_not_include_response_content()
    {
        using var httpClient = new HttpClient(new StubHandler(_ =>
            new HttpResponseMessage(HttpStatusCode.Forbidden)
            {
                Content = new StringContent("sensitive-response-content")
            }));

        var act = () => KeyVaultSecretValueResolver.ResolveAsync(
            new Uri("https://kv-test.vault.azure.net/secrets/key/version"),
            new StubCredential(),
            httpClient,
            CancellationToken.None);

        var exception = await act.Should().ThrowAsync<InvalidOperationException>();
        exception.WithMessage("*HTTP 403*");
        exception.Which.Message.Should().NotContain("sensitive-response-content");
    }

    private sealed class StubCredential : TokenCredential
    {
        public string[] RequestedScopes { get; private set; } = [];

        public override AccessToken GetToken(
            TokenRequestContext requestContext,
            CancellationToken cancellationToken)
        {
            RequestedScopes = requestContext.Scopes;
            return new AccessToken("test-token", DateTimeOffset.UtcNow.AddMinutes(5));
        }

        public override ValueTask<AccessToken> GetTokenAsync(
            TokenRequestContext requestContext,
            CancellationToken cancellationToken)
            => ValueTask.FromResult(GetToken(requestContext, cancellationToken));
    }

    private sealed class StubHandler(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
            => Task.FromResult(responseFactory(request));
    }
}
