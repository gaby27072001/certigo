using System.Collections;
using System.Collections.Immutable;
using System.Net;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Tests;

internal sealed class TestFunctionContext : FunctionContext
{
    private IDictionary<object, object> _items = new Dictionary<object, object>();
    private IServiceProvider _instanceServices = new TestServiceProvider();

    public override string InvocationId { get; } = Guid.NewGuid().ToString("n");
    public override string FunctionId { get; } = "test-function";
    public override TraceContext TraceContext { get; } = new TestTraceContext();
    public override BindingContext BindingContext { get; } = new TestBindingContext();
    public override RetryContext RetryContext { get; } = new TestRetryContext();
    public override FunctionDefinition FunctionDefinition { get; } = new TestFunctionDefinition();
    public override IInvocationFeatures Features { get; } = new TestInvocationFeatures();

    public override IServiceProvider InstanceServices
    {
        get => _instanceServices;
        set => _instanceServices = value;
    }

    public override IDictionary<object, object> Items
    {
        get => _items;
        set => _items = value;
    }

    public static TestFunctionContext Authenticated(
        string userId = "user-1",
        string displayName = "Tester",
        params string[] roles)
    {
        var context = new TestFunctionContext();
        context.Items["User"] = CreatePrincipal(userId, displayName, roles);
        return context;
    }

    private static ClaimsPrincipal CreatePrincipal(
        string userId,
        string displayName,
        IReadOnlyList<string> roles)
        => new(new ClaimsIdentity(
            new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId),
                new Claim(ClaimTypes.Name, displayName),
            }.Concat(roles.Select(role => new Claim(ClaimTypes.Role, role))),
            authenticationType: "test"));
}

internal sealed class TestHttpRequestData : HttpRequestData
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly Stream _body;

    public TestHttpRequestData(
        FunctionContext functionContext,
        string method,
        string url,
        object? jsonBody = null,
        HttpHeadersCollection? headers = null)
        : base(functionContext)
    {
        Method = method;
        Url = new Uri(url, UriKind.Absolute);
        Headers = headers ?? new HttpHeadersCollection();
        _body = BuildBody(jsonBody);
    }

    public override Stream Body => _body;
    public override HttpHeadersCollection Headers { get; }
    public override IReadOnlyCollection<IHttpCookie> Cookies { get; } = Array.Empty<IHttpCookie>();
    public override Uri Url { get; }
    public override IEnumerable<ClaimsIdentity> Identities { get; } = Array.Empty<ClaimsIdentity>();
    public override string Method { get; }

    public override HttpResponseData CreateResponse() => new TestHttpResponseData(FunctionContext);

    private static Stream BuildBody(object? jsonBody)
    {
        if (jsonBody is null)
        {
            return new MemoryStream();
        }

        var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(jsonBody, JsonOptions));
        return new MemoryStream(bytes);
    }
}

internal sealed class TestHttpResponseData(FunctionContext functionContext) : HttpResponseData(functionContext)
{
    public override HttpStatusCode StatusCode { get; set; } = HttpStatusCode.OK;
    public override HttpHeadersCollection Headers { get; set; } = new();
    public override Stream Body { get; set; } = new MemoryStream();
    public override HttpCookies Cookies { get; } = new TestHttpCookies();
}

internal static class TestHttpResponseDataExtensions
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static async Task<string> ReadBodyAsStringAsync(this HttpResponseData response)
    {
        response.Body.Position = 0;
        using var reader = new StreamReader(response.Body, Encoding.UTF8, leaveOpen: true);
        return await reader.ReadToEndAsync();
    }

    public static async Task<T> ReadJsonAsync<T>(this HttpResponseData response)
        where T : notnull
        => JsonSerializer.Deserialize<T>(await response.ReadBodyAsStringAsync(), JsonOptions)
           ?? throw new InvalidOperationException("Response body could not be deserialized.");
}

internal sealed class TestInvocationFeatures : IInvocationFeatures
{
    private readonly Dictionary<Type, object> _features = new();

    public IEnumerator<KeyValuePair<Type, object>> GetEnumerator() => _features.GetEnumerator();

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    public void Set<T>(T instance) => _features[typeof(T)] = instance!;

    public T Get<T>() => _features.TryGetValue(typeof(T), out var instance) ? (T)instance : default!;
}

internal sealed class TestFunctionDefinition : FunctionDefinition
{
    public override ImmutableArray<FunctionParameter> Parameters => ImmutableArray<FunctionParameter>.Empty;
    public override string PathToAssembly => string.Empty;
    public override string EntryPoint => string.Empty;
    public override string Id => "test-definition";
    public override string Name => "test-definition";
    public override IImmutableDictionary<string, BindingMetadata> InputBindings
        => ImmutableDictionary<string, BindingMetadata>.Empty;
    public override IImmutableDictionary<string, BindingMetadata> OutputBindings
        => ImmutableDictionary<string, BindingMetadata>.Empty;
}

internal sealed class TestTraceContext : TraceContext
{
    public override string TraceParent => string.Empty;
    public override string TraceState => string.Empty;
}

internal sealed class TestBindingContext : BindingContext
{
    public override IReadOnlyDictionary<string, object?> BindingData => new Dictionary<string, object?>();
}

internal sealed class TestRetryContext : RetryContext
{
    public override int RetryCount => 0;
    public override int MaxRetryCount => 0;
}

internal sealed class TestHttpCookies : HttpCookies
{
    public override void Append(string name, string value)
    {
    }

    public override void Append(IHttpCookie cookie)
    {
    }

    public override IHttpCookie CreateNew() => new TestHttpCookie();
}

internal sealed class TestHttpCookie : IHttpCookie
{
    public string Domain => string.Empty;
    public DateTimeOffset? Expires => null;
    public bool? HttpOnly => null;
    public double? MaxAge => null;
    public string Name => string.Empty;
    public string Path => string.Empty;
    public SameSite SameSite => SameSite.None;
    public bool? Secure => null;
    public string Value => string.Empty;
}

internal sealed class TestServiceProvider : IServiceProvider
{
    public object? GetService(Type serviceType) => null;
}
