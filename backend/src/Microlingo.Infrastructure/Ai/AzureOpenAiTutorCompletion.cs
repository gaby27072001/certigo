using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Azure.Core;
using Microsoft.Extensions.Logging;
using Microlingo.Application.Abstractions;

namespace Microlingo.Infrastructure.Ai;

public sealed record TutorLlmOptions(
    Uri Endpoint,
    string Deployment,
    string ApiVersion,
    string? ApiKey,
    int MaxOutputTokens);

/// Azure OpenAI-backed optional tutor completion. It returns only the raw model
/// text; grounding, parsing, and guardrails stay in the Application layer.
public sealed class AzureOpenAiTutorCompletion(
    HttpClient httpClient,
    TokenCredential credential,
    ILogger<AzureOpenAiTutorCompletion> logger,
    TutorLlmOptions options) : ITutorCompletion
{
    private const string AzureCognitiveServicesScope = "https://cognitiveservices.azure.com/.default";

    public async Task<string?> CompleteAsync(
        string systemPrompt,
        string userPrompt,
        CancellationToken cancellationToken = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, BuildRequestUri())
        {
            Content = JsonContent.Create(new
            {
                messages = new object[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userPrompt }
                },
                temperature = 0.2,
                max_tokens = options.MaxOutputTokens,
                response_format = new { type = "json_object" }
            })
        };

        await ApplyAuthenticationAsync(request, cancellationToken);

        HttpResponseMessage response;
        try
        {
            response = await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        }
        catch (OperationCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(ex, "Tutor LLM request timed out.");
            throw new TutorCompletionUnavailableException("Tutor LLM request timed out.", ex);
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "Tutor LLM request failed before a response was received.");
            throw new TutorCompletionUnavailableException("Tutor LLM request failed before a response was received.", ex);
        }

        using (response)
        {
            if (!response.IsSuccessStatusCode)
            {
                var detail = await ReadErrorDetailAsync(response, cancellationToken);
                LogFailure(response.StatusCode, detail);
                throw new TutorCompletionUnavailableException(
                    $"Tutor LLM request failed with status {(int)response.StatusCode} ({response.StatusCode}).");
            }

            try
            {
                await using var payload = await response.Content.ReadAsStreamAsync(cancellationToken);
                using var document = await JsonDocument.ParseAsync(payload, cancellationToken: cancellationToken);
                var content = TryReadAssistantContent(document.RootElement);
                if (string.IsNullOrWhiteSpace(content))
                {
                    logger.LogWarning("Tutor LLM response did not contain assistant text.");
                    return null;
                }

                return content;
            }
            catch (JsonException ex)
            {
                logger.LogWarning(ex, "Tutor LLM returned malformed JSON.");
                return null;
            }
        }
    }

    private async Task ApplyAuthenticationAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(options.ApiKey))
        {
            request.Headers.Add("api-key", options.ApiKey);
            return;
        }

        AccessToken token;
        try
        {
            token = await credential.GetTokenAsync(
                new TokenRequestContext([AzureCognitiveServicesScope]),
                cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(ex, "Tutor LLM could not acquire an Azure AD access token.");
            throw new TutorCompletionUnavailableException(
                "Tutor LLM could not acquire an Azure AD access token.", ex);
        }

        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
    }

    private Uri BuildRequestUri()
        => new(options.Endpoint,
            $"openai/deployments/{Uri.EscapeDataString(options.Deployment)}/chat/completions?api-version={Uri.EscapeDataString(options.ApiVersion)}");

    private void LogFailure(HttpStatusCode statusCode, string detail)
    {
        if (statusCode == HttpStatusCode.TooManyRequests || (int)statusCode >= 500)
        {
            logger.LogWarning("Tutor LLM request failed with status {StatusCode}: {Detail}", (int)statusCode, detail);
            return;
        }

        logger.LogError("Tutor LLM request failed with status {StatusCode}: {Detail}", (int)statusCode, detail);
    }

    private static async Task<string> ReadErrorDetailAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        try
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            if (string.IsNullOrWhiteSpace(body))
            {
                return "empty response body";
            }

            body = body.Trim();
            return body.Length <= 1024 ? body : $"{body[..1024]}…";
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !cancellationToken.IsCancellationRequested)
        {
            return $"unable to read response body: {ex.Message}";
        }
    }

    private static string? TryReadAssistantContent(JsonElement root)
    {
        if (!root.TryGetProperty("choices", out var choices)
            || choices.ValueKind != JsonValueKind.Array
            || choices.GetArrayLength() == 0)
        {
            return null;
        }

        var first = choices[0];
        if (!first.TryGetProperty("message", out var message)
            || !message.TryGetProperty("content", out var content))
        {
            return null;
        }

        if (content.ValueKind == JsonValueKind.String)
        {
            return content.GetString();
        }

        if (content.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var parts = new List<string>();
        foreach (var segment in content.EnumerateArray())
        {
            if (segment.ValueKind == JsonValueKind.Object
                && segment.TryGetProperty("text", out var text)
                && text.ValueKind == JsonValueKind.String
                && !string.IsNullOrWhiteSpace(text.GetString()))
            {
                parts.Add(text.GetString()!);
            }
        }

        return parts.Count == 0 ? null : string.Concat(parts);
    }
}
