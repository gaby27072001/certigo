using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace Certigo.VivaLearning.Poc;

public interface IVivaLearningGraphClient
{
    Task<LearningProviderDto> RegisterProviderAsync(
        LearningProviderWriteDto provider,
        CancellationToken cancellationToken = default);

    Task<LearningContentDto> PublishContentAsync(
        string providerId,
        LearningContentWriteDto content,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<LearningCourseActivityDto>> ListMyAssignmentsAsync(
        CancellationToken cancellationToken = default);

    Task SyncAssignmentProgressAsync(
        string providerId,
        string activityId,
        LearningCourseActivityUpdateDto update,
        CancellationToken cancellationToken = default);
}

public sealed class VivaLearningGraphClient : IVivaLearningGraphClient, IDisposable
{
    private const string LearningAssignmentType = "#microsoft.graph.learningAssignment";
    private readonly HttpClient _httpClient;
    private readonly VivaLearningPocOptions _options;

    public VivaLearningGraphClient(
        FixtureGraphMessageHandler fixtureHandler,
        VivaLearningPocOptions options)
    {
        ArgumentNullException.ThrowIfNull(fixtureHandler);
        if (!options.GraphBaseUri.IsAbsoluteUri
            || options.GraphBaseUri.Scheme != Uri.UriSchemeHttps
            || !string.Equals(options.GraphBaseUri.Host, "graph.microsoft.com", StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException(
                "The Viva Learning POC only permits the Microsoft Graph HTTPS endpoint.",
                nameof(options));
        }

        var normalizedGraphBaseUri = EnsureTrailingSlash(options.GraphBaseUri);
        if (!string.Equals(normalizedGraphBaseUri.AbsolutePath, "/v1.0/", StringComparison.Ordinal)
            || !string.IsNullOrEmpty(normalizedGraphBaseUri.Query)
            || !string.IsNullOrEmpty(normalizedGraphBaseUri.Fragment)
            || !string.IsNullOrEmpty(normalizedGraphBaseUri.UserInfo)
            || !normalizedGraphBaseUri.IsDefaultPort)
        {
            throw new ArgumentException(
                "The Viva Learning POC only permits https://graph.microsoft.com/v1.0/.",
                nameof(options));
        }

        _httpClient = new HttpClient(fixtureHandler, disposeHandler: false);
        _options = options;
        _httpClient.BaseAddress = normalizedGraphBaseUri;
    }

    public void Dispose() => _httpClient.Dispose();

    public Task<LearningProviderDto> RegisterProviderAsync(
        LearningProviderWriteDto provider,
        CancellationToken cancellationToken = default)
        => SendJsonAsync<LearningProviderWriteDto, LearningProviderDto>(
            HttpMethod.Post,
            "employeeExperience/learningProviders",
            provider,
            HttpStatusCode.Created,
            cancellationToken);

    public Task<LearningContentDto> PublishContentAsync(
        string providerId,
        LearningContentWriteDto content,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(providerId);
        ArgumentNullException.ThrowIfNull(content);
        ArgumentException.ThrowIfNullOrWhiteSpace(content.ExternalId);

        var externalId = EscapeODataStringLiteral(content.ExternalId);
        var path =
            $"employeeExperience/learningProviders/{Uri.EscapeDataString(providerId)}/"
            + $"learningContents(externalId='{externalId}')";

        return SendJsonAsync<LearningContentWriteDto, LearningContentDto>(
            HttpMethod.Patch,
            path,
            content,
            HttpStatusCode.Accepted,
            cancellationToken);
    }

    public async Task<IReadOnlyList<LearningCourseActivityDto>> ListMyAssignmentsAsync(
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        var assignments = new List<LearningCourseActivityDto>();
        var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        Uri? next = new(_httpClient.BaseAddress!, "me/employeeExperience/learningCourseActivities");

        while (next is not null)
        {
            if (!visited.Add(next.AbsoluteUri))
            {
                throw new VivaLearningGraphException("Microsoft Graph returned a pagination loop.");
            }

            ValidateGraphUri(next);
            using var request = new HttpRequestMessage(HttpMethod.Get, next);
            request.Headers.TryAddWithoutValidation("Prefer", "include-unknown-enum-members");

            var page = await SendAsync<GraphCollectionResponse<LearningCourseActivityDto>>(
                request,
                HttpStatusCode.OK,
                cancellationToken);

            assignments.AddRange(page.Value.Where(item =>
                string.Equals(item.ODataType, LearningAssignmentType, StringComparison.Ordinal)));
            next = ParseNextLink(page.NextLink);
        }

        return assignments;
    }

    public async Task SyncAssignmentProgressAsync(
        string providerId,
        string activityId,
        LearningCourseActivityUpdateDto update,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(providerId);
        ArgumentException.ThrowIfNullOrWhiteSpace(activityId);
        ArgumentNullException.ThrowIfNull(update);
        EnsureEnabled();

        var path =
            $"employeeExperience/learningProviders/{Uri.EscapeDataString(providerId)}/"
            + $"learningCourseActivities/{Uri.EscapeDataString(activityId)}";
        using var request = new HttpRequestMessage(HttpMethod.Patch, path)
        {
            Content = JsonContent.Create(update, options: VivaLearningJson.Options)
        };
        using var response = await _httpClient.SendAsync(request, cancellationToken);
        await EnsureStatusAsync(response, HttpStatusCode.NoContent, cancellationToken);
    }

    private async Task<TResponse> SendJsonAsync<TRequest, TResponse>(
        HttpMethod method,
        string path,
        TRequest body,
        HttpStatusCode expectedStatus,
        CancellationToken cancellationToken)
    {
        EnsureEnabled();
        using var request = new HttpRequestMessage(method, path)
        {
            Content = JsonContent.Create(body, options: VivaLearningJson.Options)
        };
        return await SendAsync<TResponse>(request, expectedStatus, cancellationToken);
    }

    private async Task<T> SendAsync<T>(
        HttpRequestMessage request,
        HttpStatusCode expectedStatus,
        CancellationToken cancellationToken)
    {
        using var response = await _httpClient.SendAsync(request, cancellationToken);
        await EnsureStatusAsync(response, expectedStatus, cancellationToken);

        await using var payload = await response.Content.ReadAsStreamAsync(cancellationToken);
        var result = await JsonSerializer.DeserializeAsync<T>(
            payload,
            VivaLearningJson.Options,
            cancellationToken);
        return result ?? throw new VivaLearningGraphException(
            $"Microsoft Graph returned an empty {typeof(T).Name} payload.");
    }

    private static async Task EnsureStatusAsync(
        HttpResponseMessage response,
        HttpStatusCode expectedStatus,
        CancellationToken cancellationToken)
    {
        if (response.StatusCode == expectedStatus)
        {
            return;
        }

        var detail = await response.Content.ReadAsStringAsync(cancellationToken);
        throw new VivaLearningGraphException(
            $"Microsoft Graph returned {(int)response.StatusCode} ({response.StatusCode}); "
            + $"expected {(int)expectedStatus} ({expectedStatus}). Body: {detail}");
    }

    private void EnsureEnabled()
    {
        if (!_options.Enabled)
        {
            throw new VivaLearningGraphException(
                $"{VivaLearningPocGate.FeatureFlag} must be true before the isolated POC can issue a request.");
        }
    }

    private Uri? ParseNextLink(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (!Uri.TryCreate(value, UriKind.Absolute, out var next))
        {
            throw new VivaLearningGraphException("Microsoft Graph returned an invalid @odata.nextLink.");
        }

        ValidateGraphUri(next);
        return next;
    }

    private static void ValidateGraphUri(Uri uri)
    {
        if (uri.Scheme != Uri.UriSchemeHttps
            || !string.Equals(uri.Host, "graph.microsoft.com", StringComparison.OrdinalIgnoreCase)
            || !uri.AbsolutePath.StartsWith("/v1.0/", StringComparison.Ordinal))
        {
            throw new VivaLearningGraphException(
                "The POC refused a pagination URI outside https://graph.microsoft.com/v1.0/.");
        }
    }

    private static string EscapeODataStringLiteral(string value)
        => Uri.EscapeDataString(value.Replace("'", "''", StringComparison.Ordinal));

    private static Uri EnsureTrailingSlash(Uri uri)
    {
        var builder = new UriBuilder(uri);
        builder.Path = $"{builder.Path.TrimEnd('/')}/";
        return builder.Uri;
    }
}
