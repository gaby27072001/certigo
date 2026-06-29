using System.Net;
using System.Net.Http.Headers;
using System.Text;
using FluentAssertions;
using Azure;
using Azure.Core;
using Microsoft.Extensions.Logging.Abstractions;
using Certigo.Application.Abstractions;
using Certigo.Infrastructure.Ai;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class AzureOpenAiTutorCompletionTests
{
    [Fact]
    public async Task CompleteAsync_targets_v1_surface_with_gpt5_body_and_api_key()
    {
        var handler = new StubHttpMessageHandler(request =>
        {
            request.Headers.Authorization.Should().BeNull();
            request.Headers.GetValues("api-key").Single().Should().Be("key-123");

            var uri = request.RequestUri!.ToString();
            uri.Should().Contain("/openai/v1/chat/completions");
            uri.Should().NotContain("api-version");
            uri.Should().NotContain("/deployments/");

            var body = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            body.Should().Contain("\"model\":\"gpt-5.4-mini\"");
            body.Should().Contain("\"max_completion_tokens\":400");
            body.Should().NotContain("\"temperature\"");
            body.Should().NotContain("max_tokens");

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

    [Fact]
    public async Task CompleteAsync_targets_classic_deployment_path_when_surface_is_classic()
    {
        var handler = new StubHttpMessageHandler(request =>
        {
            var uri = request.RequestUri!.ToString();
            uri.Should().Contain("/openai/deployments/gpt-5.4-mini/chat/completions");
            uri.Should().Contain("api-version=2024-10-21");
            return JsonResponse("""
            {
              "choices": [
                {
                  "message": {
                    "content": "{\"headline\":\"Classic\",\"points\":[\"Point\"],\"encouragement\":\"Oui\",\"citedConceptIds\":[\"c1\"]}"
                  }
                }
              ]
            }
            """);
        });

        var completion = CreateCompletion(handler, apiKey: "key-123", apiSurface: TutorLlmApiSurface.AzureClassic);

        var result = await completion.CompleteAsync("system", "user");

        result.Should().Contain("\"headline\":\"Classic\"");
    }

    private static AzureOpenAiTutorCompletion CreateCompletion(
        HttpMessageHandler handler,
        string? apiKey = null,
        TutorLlmApiSurface apiSurface = TutorLlmApiSurface.V1)
        => new(
            new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(5) },
            new StubTokenCredential(),
            NullLogger<AzureOpenAiTutorCompletion>.Instance,
            new TutorLlmOptions(
                apiSurface == TutorLlmApiSurface.AzureClassic
                    ? new Uri("https://contoso.openai.azure.com/")
                    : new Uri("https://certigo-openai.services.ai.azure.com/api/projects/certigo-dev/openai/v1/"),
                "gpt-5.4-mini",
                apiSurface == TutorLlmApiSurface.AzureClassic ? "2024-10-21" : null,
                apiKey,
                400,
                apiSurface));

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
