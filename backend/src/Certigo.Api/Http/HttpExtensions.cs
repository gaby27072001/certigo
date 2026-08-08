using System.Net;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Application.Dtos;

namespace Certigo.Api.Http;

public static class HttpExtensions
{
    private static readonly JsonSerializerOptions JsonOptions = CreateOptions();

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        var resolver = new DefaultJsonTypeInfoResolver();
        resolver.Modifiers.Add(typeInfo =>
        {
            if (typeInfo.Type != typeof(UserProfileDto))
            {
                return;
            }

            foreach (var property in typeInfo.Properties.Where(property =>
                         property.Name is "economyReceipts" or "appliedEconomyOperations"))
            {
                property.ShouldSerialize = static (_, _) => false;
            }
        });
        options.TypeInfoResolver = resolver;
        return options;
    }

    public static async Task<HttpResponseData> JsonAsync<T>(
        this HttpRequestData request,
        T value,
        HttpStatusCode statusCode = HttpStatusCode.OK,
        CancellationToken cancellationToken = default)
    {
        var response = request.CreateResponse(statusCode);
        response.Headers.Add("Content-Type", "application/json; charset=utf-8");
        await response.WriteStringAsync(JsonSerializer.Serialize(value, JsonOptions), cancellationToken);
        return response;
    }

    public static async Task<JsonResponseWriter> JsonAsync<T>(
        this HttpResponseData response,
        T value,
        CancellationToken cancellationToken = default)
    {
        response.Headers.Add("Content-Type", "application/problem+json");
        await response.WriteStringAsync(JsonSerializer.Serialize(value, JsonOptions), cancellationToken);
        return new JsonResponseWriter(response);
    }

    public static async Task<T> ReadJsonAsync<T>(this HttpRequestData request, CancellationToken cancellationToken = default)
        where T : notnull
    {
        try
        {
            var value = await JsonSerializer.DeserializeAsync<T>(request.Body, JsonOptions, cancellationToken);
            return value ?? throw new BadRequestException("Request body is required.");
        }
        catch (JsonException ex)
        {
            // Malformed JSON is a client error (400), not a server fault (500).
            throw new BadRequestException($"Invalid JSON request body: {ex.Message}");
        }
    }

    public static Task<HttpResponseData> NotFound(this HttpRequestData request, string message, CancellationToken cancellationToken = default)
        => request.JsonAsync(new { error = message }, HttpStatusCode.NotFound, cancellationToken);

    public static ClaimsPrincipal GetUser(this FunctionContext context)
        => context.Items.TryGetValue("User", out var value) && value is ClaimsPrincipal principal
            ? principal
            : throw new UnauthorizedAccessException("No authenticated user is available.");
}

public readonly record struct JsonResponseWriter(HttpResponseData Response);

/// Signals a client-side error (malformed/missing body, bad parameters) so the
/// exception middleware can answer 400 Bad Request instead of a generic 500.
public sealed class BadRequestException(string message) : Exception(message);
