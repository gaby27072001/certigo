using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FluentAssertions;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// The one real, over-the-network proof that the Azure OpenAI / Microsoft Foundry
/// tutor path actually works end-to-end against a deployed environment:
/// register → login → JWT → <c>POST /api/tutor/explain</c> → 200 with a genuine
/// (non-fallback) LLM explanation.
///
/// Skipped by default — see <see cref="TutorLlmLiveEnvironment"/> for exactly how
/// and when to enable it. This test makes real HTTP calls against
/// <c>CERTIGO_TUTOR_API_BASE_URL</c>; it must never run unattended in CI.
/// </summary>
public sealed class TutorLlmLiveEndToEndTests
{
    // Mirrors Certigo.Api.Http.HttpExtensions' serializer wiring exactly, so request/
    // response shapes round-trip identically to what the real API sends and expects.
    private static readonly JsonSerializerOptions JsonOptions = CreateOptions();

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        return options;
    }

    [TutorLlmLiveFact]
    public async Task ExplainAnswer_ReturnsRealLlmExplanation_AgainstDeployedEnvironment()
    {
        var config = TutorLlmLiveEnvironment.ReadRequiredConfig();
        using var client = new HttpClient { BaseAddress = config.BaseUrl, Timeout = TimeSpan.FromSeconds(30) };

        // 1) Register a throwaway learner. A fresh GUID email guarantees this is
        // always a brand-new account, never a collision with a prior run.
        var email = $"tutor-e2e-{Guid.NewGuid():N}@certigo.test";
        const string password = "Certigo-Tutor-E2E-2026!";
        var registerResponse = await client.PostAsJsonAsync(
            "/api/auth/register", new RegisterRequest(email, password), JsonOptions);
        var registerBody = await registerResponse.Content.ReadAsStringAsync();
        registerResponse.StatusCode.Should().Be(
            HttpStatusCode.Created,
            $"registration should succeed for a fresh email; body: {registerBody}");

        // 2) Log in to obtain a JWT (email verification is a soft banner, never a
        // login blocker — see AuthResultDto.EmailVerified).
        var loginResponse = await client.PostAsJsonAsync(
            "/api/auth/login", new LoginRequest(email, password), JsonOptions);
        var loginBody = await loginResponse.Content.ReadAsStringAsync();
        loginResponse.StatusCode.Should().Be(
            HttpStatusCode.OK,
            $"login should succeed immediately after registration; body: {loginBody}");
        var authResult = JsonSerializer.Deserialize<AuthResultDto>(loginBody, JsonOptions);
        authResult.Should().NotBeNull();
        authResult!.AccessToken.Should().NotBeNullOrWhiteSpace();

        // 3) Ask the tutor to explain a real, already-seeded quiz item. An empty
        // selection is a valid (if pedagogically uninteresting) request — this test
        // only asserts on connectivity and completion source, not on the grounded
        // pedagogy itself.
        using var explainRequest = new HttpRequestMessage(HttpMethod.Post, "/api/tutor/explain")
        {
            Content = JsonContent.Create(
                new TutorExplainRequest(config.TrackId, config.LessonId, config.ItemId, new List<string>()),
                options: JsonOptions)
        };
        explainRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", authResult.AccessToken);

        var explainResponse = await client.SendAsync(explainRequest);
        var explainBody = await explainResponse.Content.ReadAsStringAsync();
        explainResponse.StatusCode.Should().Be(
            HttpStatusCode.OK,
            $"tutor/explain should succeed for a valid trackId/lessonId/itemId; body: {explainBody}");

        var explanation = JsonSerializer.Deserialize<TutorExplanationDto>(explainBody, JsonOptions);
        explanation.Should().NotBeNull();
        explanation!.Source.Should().Be(
            "ai",
            "a 'grounded' source means the deterministic fallback engaged (provider error, " +
            "empty/rejected response, or a guardrail rejection) instead of a real LLM completion " +
            "— check RBAC (Cognitive Services OpenAI User), the model deployment, and quota; " +
            $"full response body: {explainBody}");
    }
}
