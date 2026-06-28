using System.Net;
using System.Net.Http.Headers;
using System.Text;
using FluentAssertions;
using Azure;
using Azure.Core;
using Microsoft.Extensions.Logging.Abstractions;
using Microlingo.Application.Abstractions;
using Microlingo.Infrastructure.Ai;
using Xunit;

namespace Microlingo.Infrastructure.Tests;

public sealed class AzureOpenAiTutorCompletionTests
{
    [Fact]
    public async Task CompleteAsync_uses_api_key_when_configured()
    {
        var handler = new StubHttpMessageHandler(request =>
        {
            request.Headers.Authorization.Should().BeNull();
            request.Headers.GetValues("api-key").Single().Should().Be("key-123");
            request.RequestUri!.ToString().Should().Contain("/openai/deployments/tutor-mini/chat/completions");
            return JsonResponse("""
            {
              "choices": [
                {
                  "message": {
                    "content": "{\"headline\":\"Bravo\",\"points\":[\"Point\"],\"encouragement\":\"Encore\",\"citedConceptIds\":[\"c1\"]}"
                  }
                }
              ]
            }
            """);
        });

        var completion = CreateCompletion(handler, apiKey: "key-123");

        var result = await completion.CompleteAsync("system", "user");

        result.Should().Contain("\"headline\":\"Bravo\"");
    }

    [Fact]
    public async Task CompleteAsync_uses_bearer_token_when_api_key_is_missing()
    {
        var handler = new StubHttpMessageHandler(request =>
        {
            request.Headers.Authorization.Should().BeEquivalentTo(
                new AuthenticationHeaderValue("Bearer", "token-abc"));
            return JsonResponse("""
            {
              "choices": [
                {
                  "message": {
                    "content": "  {\"headline\":\"Salut\",\"points\":[\"Point\"],\"encouragement\":\"Oui\",\"citedConceptIds\":[\"c1\"]}  "
                  }
                }
              ]
            }
            """);
        });

        var completion = CreateCompletion(handler);

        var result = await completion.CompleteAsync("system", "user");

        result.Should().Contain("\"headline\":\"Salut\"");
    }

    [Fact]
    public async Task CompleteAsync_returns_null_when_response_has_no_message_content()
    {
        var handler = new StubHttpMessageHandler(_ => JsonResponse("""{ "choices": [ { "message": {} } ] }"""));
        var completion = CreateCompletion(handler);

        var result = await completion.CompleteAsync("system", "user");

        result.Should().BeNull();
    }

    [Fact]
    public async Task CompleteAsync_throws_controlled_exception_on_service_failure()
    {
        var handler = new StubHttpMessageHandler(_ =>
            new HttpResponseMessage(HttpStatusCode.TooManyRequests)
            {
                Content = new StringContent("""{ "error": { "message": "rate limited" } }""", Encoding.UTF8, "application/json")
            });
        var completion = CreateCompletion(handler);

        var act = async () => await completion.CompleteAsync("system", "user");

        await act.Should().ThrowAsync<TutorCompletionUnavailableException>()
            .WithMessage("*429*");
    }

    private static AzureOpenAiTutorCompletion CreateCompletion(HttpMessageHandler handler, string? apiKey = null)
        => new(
            new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(5) },
            new StubTokenCredential(),
            NullLogger<AzureOpenAiTutorCompletion>.Instance,
            new TutorLlmOptions(
                new Uri("https://contoso.openai.azure.com/"),
                "tutor-mini",
                "2024-10-21",
                apiKey,
                400));

    private static HttpResponseMessage JsonResponse(string body)
        => new(HttpStatusCode.OK)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        };

    private sealed class StubTokenCredential : TokenCredential
    {
        public override AccessToken GetToken(TokenRequestContext requestContext, CancellationToken cancellationToken)
            => new("token-abc", DateTimeOffset.UtcNow.AddMinutes(5));

        public override ValueTask<AccessToken> GetTokenAsync(TokenRequestContext requestContext, CancellationToken cancellationToken)
            => ValueTask.FromResult(GetToken(requestContext, cancellationToken));
    }

    private sealed class StubHttpMessageHandler(Func<HttpRequestMessage, HttpResponseMessage> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(send(request));
    }
}
