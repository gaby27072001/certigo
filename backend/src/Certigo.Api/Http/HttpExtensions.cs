using System.Net;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Http;

public static class HttpExtensions
{
    private static readonly JsonSerializerOptions JsonOptions = CreateOptions();

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
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
        => await DeserializeAsync<T>(request.Body, cancellationToken);

    public static async Task<T> ReadJsonAsync<T>(
        this HttpRequestData request,
        long maxBytes,
        CancellationToken cancellationToken = default)
        where T : notnull
    {
        if (maxBytes <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxBytes));
        }

        await using var limited = new SizeLimitedReadStream(request.Body, maxBytes);
        return await DeserializeAsync<T>(limited, cancellationToken);
    }

    private static async Task<T> DeserializeAsync<T>(
        Stream body,
        CancellationToken cancellationToken)
        where T : notnull
    {
        try
        {
            var value = await JsonSerializer.DeserializeAsync<T>(body, JsonOptions, cancellationToken);
            return value ?? throw new BadRequestException("Request body is required.");
        }
        catch (JsonException ex)
        {
            // Malformed JSON is a client error (400), not a server fault (500).
            throw new BadRequestException($"Invalid JSON request body: {ex.Message}");
        }
    }

    private sealed class SizeLimitedReadStream(Stream inner, long maxBytes) : Stream
    {
        private long _bytesRead;

        public override bool CanRead => inner.CanRead;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }

        public override int Read(byte[] buffer, int offset, int count)
            => Track(inner.Read(buffer, offset, count));

        public override int Read(Span<byte> buffer)
            => Track(inner.Read(buffer));

        public override async Task<int> ReadAsync(
            byte[] buffer,
            int offset,
            int count,
            CancellationToken cancellationToken)
            => Track(await inner.ReadAsync(buffer, offset, count, cancellationToken));

        public override async ValueTask<int> ReadAsync(
            Memory<byte> buffer,
            CancellationToken cancellationToken = default)
            => Track(await inner.ReadAsync(buffer, cancellationToken));

        public override void Flush()
        {
        }

        public override long Seek(long offset, SeekOrigin origin)
            => throw new NotSupportedException();

        public override void SetLength(long value)
            => throw new NotSupportedException();

        public override void Write(byte[] buffer, int offset, int count)
            => throw new NotSupportedException();

        protected override void Dispose(bool disposing)
        {
            // The request owns the underlying body stream.
            base.Dispose(disposing);
        }

        private int Track(int count)
        {
            _bytesRead += count;
            if (_bytesRead > maxBytes)
            {
                throw new BadRequestException("Request body is too large.");
            }

            return count;
        }
    }

    public static Task<HttpResponseData> NotFound(this HttpRequestData request, string message, CancellationToken cancellationToken = default)
        => request.JsonAsync(new { error = message }, HttpStatusCode.NotFound, cancellationToken);

    public static ClaimsPrincipal GetUser(this FunctionContext context)
        => context.Items.TryGetValue("User", out var value) && value is ClaimsPrincipal principal
            ? principal
            : throw new UnauthorizedAccessException("No authenticated user is available.");

    public static ClaimsPrincipal GetUserInRole(this FunctionContext context, string role)
    {
        var principal = context.GetUser();
        var hasRole = principal.IsInRole(role)
            || principal.Claims.Any(claim =>
                (claim.Type is "roles" or "role"
                 || claim.Type == ClaimTypes.Role)
                && string.Equals(claim.Value, role, StringComparison.Ordinal));
        return hasRole
            ? principal
            : throw new ForbiddenException($"The '{role}' role is required.");
    }
}

public readonly record struct JsonResponseWriter(HttpResponseData Response);

/// Signals a client-side error (malformed/missing body, bad parameters) so the
/// exception middleware can answer 400 Bad Request instead of a generic 500.
public sealed class BadRequestException(string message) : Exception(message);

public sealed class ForbiddenException(string message) : Exception(message);
