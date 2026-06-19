using System.Net;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Microlingo.Api.Http;

public static class HttpExtensions
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

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
        var value = await JsonSerializer.DeserializeAsync<T>(request.Body, JsonOptions, cancellationToken);
        return value ?? throw new InvalidOperationException("Request body is required.");
    }

    public static Task<HttpResponseData> NotFound(this HttpRequestData request, string message, CancellationToken cancellationToken = default)
        => request.JsonAsync(new { error = message }, HttpStatusCode.NotFound, cancellationToken);

    public static ClaimsPrincipal GetUser(this FunctionContext context)
        => context.Items.TryGetValue("User", out var value) && value is ClaimsPrincipal principal
            ? principal
            : throw new UnauthorizedAccessException("No authenticated user is available.");
}

public readonly record struct JsonResponseWriter(HttpResponseData Response);
