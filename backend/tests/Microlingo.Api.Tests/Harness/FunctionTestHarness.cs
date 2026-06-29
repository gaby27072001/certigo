using System.Collections;
using System.Collections.Immutable;
using System.Net;
using System.Reflection;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Microlingo.Api.Tests;

// Hand-rolled doubles for the Azure Functions isolated-worker SDK (Worker.Core 1.20.0).
// HttpRequestData / HttpResponseData / FunctionContext / FunctionDefinition are abstract
// classes with no in-box test doubles, so the harness implements the minimal surface the
// production middleware and functions actually exercise. No production code is touched.

/// <summary>Backing store for <see cref="FunctionContext.Features"/>.</summary>
internal sealed class FakeInvocationFeatures : IInvocationFeatures
{
    private readonly Dictionary<Type, object> _features = new();

    public void Set<T>(T instance)
    {
        if (instance is not null)
        {
            _features[typeof(T)] = instance;
        }
    }

    public T Get<T>() => _features.TryGetValue(typeof(T), out var value) ? (T)value : default!;

    /// <summary>Registers a feature under a runtime <see cref="Type"/> key (for internal SDK feature interfaces).</summary>
    public void SetRaw(Type featureType, object instance) => _features[featureType] = instance;

    public IEnumerator<KeyValuePair<Type, object>> GetEnumerator() => _features.GetEnumerator();

    IEnumerator IEnumerable.GetEnumerator() => _features.GetEnumerator();
}

internal sealed class FakeFunctionDefinition : FunctionDefinition
{
    public FakeFunctionDefinition(string name) => Name = name;

    public override ImmutableArray<FunctionParameter> Parameters { get; } = ImmutableArray<FunctionParameter>.Empty;

    public override string PathToAssembly { get; } = string.Empty;

    public override string EntryPoint { get; } = string.Empty;

    public override string Id { get; } = "test-function";

    public override string Name { get; }

    public override IImmutableDictionary<string, BindingMetadata> InputBindings { get; } =
        ImmutableDictionary<string, BindingMetadata>.Empty;

    public override IImmutableDictionary<string, BindingMetadata> OutputBindings { get; } =
        ImmutableDictionary<string, BindingMetadata>.Empty;
}

/// <summary>
/// A <see cref="DispatchProxy"/> implementation of the SDK-internal
/// <c>IFunctionBindingsFeature</c> interface. The interface cannot be implemented directly
/// because it is <c>internal</c> in Worker.Core, so the proxy is created reflectively against
/// the runtime <see cref="Type"/> and captures the invocation result the SDK assigns through
/// <c>context.GetInvocationResult().Value = response</c>.
/// </summary>
public class BindingsFeatureProxy : DispatchProxy
{
    private static readonly Dictionary<string, object?> EmptyData = new();

    public object? InvocationResult { get; set; }

    protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
    {
        switch (targetMethod?.Name)
        {
            case "get_InvocationResult":
                return InvocationResult;
            case "set_InvocationResult":
                InvocationResult = args is { Length: > 0 } ? args[0] : null;
                return null;
            case "get_TriggerMetadata":
            case "get_InputData":
            case "get_OutputBindingData":
                return EmptyData;
            default:
                return null;
        }
    }
}

/// <summary>
/// Reflection factory that creates a <see cref="BindingsFeatureProxy"/> typed as the internal
/// <c>IFunctionBindingsFeature</c> interface so it can be registered into the context features.
/// </summary>
internal static class BindingsFeature
{
    public static readonly Type FeatureType = typeof(IInvocationFeatures).Assembly
        .GetType("Microsoft.Azure.Functions.Worker.Context.Features.IFunctionBindingsFeature", throwOnError: true)!;

    // .NET 8 exposes two public static DispatchProxy.Create methods (the generic
    // Create<T, TProxy>() and a non-generic Create(Type, Type)), so GetMethod(name) is
    // ambiguous. Select the parameterless generic definition explicitly.
    private static readonly MethodInfo CreateProxy = typeof(DispatchProxy)
        .GetMethods(BindingFlags.Public | BindingFlags.Static)
        .Single(m => m.Name == nameof(DispatchProxy.Create)
            && m.IsGenericMethodDefinition
            && m.GetGenericArguments().Length == 2
            && m.GetParameters().Length == 0)
        .MakeGenericMethod(FeatureType, typeof(BindingsFeatureProxy));

    public static (object Feature, BindingsFeatureProxy Capture) Create()
    {
        var proxy = CreateProxy.Invoke(null, null)!;
        return (proxy, (BindingsFeatureProxy)proxy);
    }
}

/// <summary>
/// Resolves the request the SDK extension <c>context.GetHttpRequestDataAsync()</c> returns.
/// A <c>null</c> request models a non-HTTP trigger.
/// </summary>
internal sealed class FakeHttpRequestDataFeature : IHttpRequestDataFeature
{
    private readonly HttpRequestData? _request;

    public FakeHttpRequestDataFeature(HttpRequestData? request) => _request = request;

    public ValueTask<HttpRequestData?> GetHttpRequestDataAsync(FunctionContext context) => new(_request);
}

internal sealed class EmptyServiceProvider : IServiceProvider
{
    public static readonly EmptyServiceProvider Instance = new();

    public object? GetService(Type serviceType) => null;
}

internal sealed class FakeFunctionContext : FunctionContext
{
    public FakeFunctionContext(IServiceProvider? instanceServices = null, string functionName = "TestFunction")
    {
        InstanceServices = instanceServices ?? EmptyServiceProvider.Instance;
        FunctionDefinition = new FakeFunctionDefinition(functionName);
    }

    public override string InvocationId { get; } = Guid.NewGuid().ToString("n");

    public override string FunctionId { get; } = "test-function-id";

    public override TraceContext TraceContext => throw new NotSupportedException("TraceContext is not used by the HTTP layer tests.");

    public override BindingContext BindingContext => throw new NotSupportedException("BindingContext is not used by the HTTP layer tests.");

    public override RetryContext RetryContext => throw new NotSupportedException("RetryContext is not used by the HTTP layer tests.");

    public override IServiceProvider InstanceServices { get; set; }

    public override FunctionDefinition FunctionDefinition { get; }

    public override IDictionary<object, object> Items { get; set; } = new Dictionary<object, object>();

    public override IInvocationFeatures Features { get; } = new FakeInvocationFeatures();
}

internal sealed class FakeHttpResponseData : HttpResponseData
{
    public FakeHttpResponseData(FunctionContext functionContext)
        : base(functionContext)
    {
    }

    public override HttpStatusCode StatusCode { get; set; } = HttpStatusCode.OK;

    public override HttpHeadersCollection Headers { get; set; } = new();

    public override Stream Body { get; set; } = new MemoryStream();

    public override HttpCookies Cookies => throw new NotSupportedException("Cookies are not used by the HTTP layer tests.");
}

internal sealed class FakeHttpRequestData : HttpRequestData
{
    public FakeHttpRequestData(
        FunctionContext functionContext,
        string method,
        Uri url,
        Stream body,
        HttpHeadersCollection headers)
        : base(functionContext)
    {
        Method = method;
        Url = url;
        Body = body;
        Headers = headers;
    }

    public override Stream Body { get; }

    public override HttpHeadersCollection Headers { get; }

    public override IReadOnlyCollection<IHttpCookie> Cookies { get; } = Array.Empty<IHttpCookie>();

    public override Uri Url { get; }

    public override IEnumerable<ClaimsIdentity> Identities { get; } = Enumerable.Empty<ClaimsIdentity>();

    public override string Method { get; }

    public FakeHttpResponseData? LastResponse { get; private set; }

    public override HttpResponseData CreateResponse()
    {
        LastResponse = new FakeHttpResponseData(FunctionContext);
        return LastResponse;
    }
}

/// <summary>The result of building a fake invocation: the context, the request, and the captured bindings.</summary>
internal sealed class HarnessInvocation
{
    private static readonly JsonSerializerOptions ProblemJson = new(JsonSerializerDefaults.Web);

    public HarnessInvocation(FakeFunctionContext context, FakeHttpRequestData? request, BindingsFeatureProxy bindings)
    {
        Context = context;
        Request = request;
        Bindings = bindings;
    }

    public FakeFunctionContext Context { get; }

    public FakeHttpRequestData? Request { get; }

    public BindingsFeatureProxy Bindings { get; }

    /// <summary>The response the middleware wrote through <c>GetInvocationResult().Value</c>, if any.</summary>
    public HttpResponseData? Response => Request?.LastResponse ?? Bindings.InvocationResult as HttpResponseData;

    public string? CorrelationId =>
        Response is not null && Response.Headers.TryGetValues("x-correlation-id", out var values)
            ? values.FirstOrDefault()
            : null;

    public async Task<string> ReadBodyAsync(HttpResponseData? response = null)
    {
        var target = response ?? Response;
        if (target is null)
        {
            return string.Empty;
        }

        target.Body.Position = 0;
        using var reader = new StreamReader(target.Body, Encoding.UTF8, leaveOpen: true);
        return await reader.ReadToEndAsync();
    }

    public async Task<ProblemPayload?> ReadProblemAsync(HttpResponseData? response = null)
    {
        var json = await ReadBodyAsync(response);
        return string.IsNullOrEmpty(json) ? null : JsonSerializer.Deserialize<ProblemPayload>(json, ProblemJson);
    }
}

/// <summary>Local mirror of the subset of <c>ProblemDetails</c> the tests assert on.</summary>
internal sealed record ProblemPayload
{
    [JsonPropertyName("title")] public string? Title { get; init; }

    [JsonPropertyName("detail")] public string? Detail { get; init; }

    [JsonPropertyName("status")] public int? Status { get; init; }

    [JsonPropertyName("correlationId")] public string? CorrelationId { get; init; }
}

internal static class FunctionTestHarness
{
    public const string BaseUrl = "https://localhost";

    /// <summary>Builds a fully wired HTTP invocation (request feature + bindings feature registered).</summary>
    public static HarnessInvocation CreateHttp(
        string method = "POST",
        string path = "/api/quiz/lesson-1/submit",
        string? body = null,
        IDictionary<string, string>? headers = null,
        IServiceProvider? services = null,
        string functionName = "TestFunction")
    {
        var context = new FakeFunctionContext(services, functionName);
        var (bindingsFeature, bindings) = BindingsFeature.Create();
        ((FakeInvocationFeatures)context.Features).SetRaw(BindingsFeature.FeatureType, bindingsFeature);

        var headerCollection = new HttpHeadersCollection();
        if (headers is not null)
        {
            foreach (var header in headers)
            {
                headerCollection.Add(header.Key, header.Value);
            }
        }

        var bodyStream = body is null
            ? new MemoryStream()
            : new MemoryStream(Encoding.UTF8.GetBytes(body));
        var url = new Uri(BaseUrl + path);
        var request = new FakeHttpRequestData(context, method, url, bodyStream, headerCollection);
        context.Features.Set<IHttpRequestDataFeature>(new FakeHttpRequestDataFeature(request));

        return new HarnessInvocation(context, request, bindings);
    }

    /// <summary>Builds a non-HTTP invocation: the HTTP request feature resolves to <c>null</c>.</summary>
    public static HarnessInvocation CreateNonHttp(
        IServiceProvider? services = null,
        string functionName = "TimerFunction")
    {
        var context = new FakeFunctionContext(services, functionName);
        var (bindingsFeature, bindings) = BindingsFeature.Create();
        ((FakeInvocationFeatures)context.Features).SetRaw(BindingsFeature.FeatureType, bindingsFeature);
        context.Features.Set<IHttpRequestDataFeature>(new FakeHttpRequestDataFeature(null));
        return new HarnessInvocation(context, null, bindings);
    }
}

/// <summary>Builds <see cref="ClaimsPrincipal"/> instances with explicit JWT-style claims.</summary>
internal static class TestPrincipal
{
    public static ClaimsPrincipal With(
        string? oid = null,
        string? sub = null,
        string? nameIdentifier = null,
        string? name = null,
        string? preferredUsername = null)
    {
        var claims = new List<Claim>();
        if (oid is not null)
        {
            claims.Add(new Claim("oid", oid));
        }

        if (sub is not null)
        {
            claims.Add(new Claim("sub", sub));
        }

        if (nameIdentifier is not null)
        {
            claims.Add(new Claim(ClaimTypes.NameIdentifier, nameIdentifier));
        }

        if (name is not null)
        {
            claims.Add(new Claim("name", name));
        }

        if (preferredUsername is not null)
        {
            claims.Add(new Claim("preferred_username", preferredUsername));
        }

        var identity = new ClaimsIdentity(claims, authenticationType: "TestAuth");
        return new ClaimsPrincipal(identity);
    }
}
