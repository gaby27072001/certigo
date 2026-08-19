using System.Net;
using System.Text;

namespace Certigo.VivaLearning.Poc;

public sealed class FixtureGraphMessageHandler(string fixtureDirectory) : HttpMessageHandler
{
    private readonly List<CapturedGraphRequest> _requests = [];

    public IReadOnlyList<CapturedGraphRequest> Requests => _requests;

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        var body = request.Content is null
            ? null
            : await request.Content.ReadAsStringAsync(cancellationToken);
        var contentHeaders = request.Content is null
            ? Enumerable.Empty<KeyValuePair<string, IEnumerable<string>>>()
            : request.Content.Headers;
        var headers = request.Headers
            .Concat(contentHeaders)
            .ToDictionary(
                header => header.Key,
                header => (IReadOnlyList<string>)header.Value.ToArray(),
                StringComparer.OrdinalIgnoreCase);

        _requests.Add(new CapturedGraphRequest(
            request.Method.Method,
            request.RequestUri!.PathAndQuery,
            body,
            headers));

        var path = Uri.UnescapeDataString(request.RequestUri.AbsolutePath);
        if (request.Method == HttpMethod.Post
            && path.EndsWith("/employeeExperience/learningProviders", StringComparison.Ordinal))
        {
            return JsonFixture(HttpStatusCode.Created, "provider-created.json");
        }

        if (request.Method == HttpMethod.Patch
            && path.Contains("/learningContents(", StringComparison.Ordinal))
        {
            return JsonFixture(HttpStatusCode.Accepted, "content-accepted.json");
        }

        if (request.Method == HttpMethod.Get
            && path.EndsWith(
                "/me/employeeExperience/learningCourseActivities",
                StringComparison.Ordinal))
        {
            return JsonFixture(HttpStatusCode.OK, "assignments-page.json");
        }

        if (request.Method == HttpMethod.Patch
            && path.Contains("/learningCourseActivities/", StringComparison.Ordinal))
        {
            return new HttpResponseMessage(HttpStatusCode.NoContent);
        }

        return new HttpResponseMessage(HttpStatusCode.BadRequest)
        {
            Content = new StringContent(
                $"No contractual fixture matches {request.Method} {request.RequestUri}.",
                Encoding.UTF8,
                "text/plain")
        };
    }

    private HttpResponseMessage JsonFixture(HttpStatusCode statusCode, string fileName)
    {
        var path = Path.Combine(fixtureDirectory, fileName);
        if (!File.Exists(path))
        {
            throw new FileNotFoundException("Contractual Viva Learning fixture not found.", path);
        }

        return new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(File.ReadAllText(path), Encoding.UTF8, "application/json")
        };
    }
}
