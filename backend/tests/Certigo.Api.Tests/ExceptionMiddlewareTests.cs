using System.Net;
using FluentAssertions;
using Certigo.Api.Http;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ExceptionMiddlewareTests
{
    private static ExceptionMiddleware CreateMiddleware()
        => new(NullLogger<ExceptionMiddleware>.Instance);

    [Fact]
    public async Task BadRequestException_MapsTo400_ProblemDetails()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context, _ => throw new BadRequestException("Adresse e-mail invalide."));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        invocation.Response.Headers.TryGetValues("Content-Type", out var contentType).Should().BeTrue();
        contentType!.Single().Should().Be("application/problem+json");

        var problem = await invocation.ReadProblemAsync();
        problem.Should().NotBeNull();
        problem!.Status.Should().Be(400);
        problem.Title.Should().Be("Invalid request");
        problem.Detail.Should().Be("Adresse e-mail invalide.");
    }

    [Fact]
    public async Task RequestValidationException_MapsTo400_ProblemDetails()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(
            invocation.Context,
            _ => throw new RequestValidationException("Duplicate item id(s) are not allowed."));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(400);
        problem.Title.Should().Be("Invalid request");
        problem.Detail.Should().Be("Duplicate item id(s) are not allowed.");
    }

    [Fact]
    public async Task ContentReleaseValidationException_MapsTo422_ProblemDetails()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(
            invocation.Context,
            _ => throw new ContentReleaseValidationException(
                "Certification catalog is invalid."));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.UnprocessableEntity);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(422);
        problem.Title.Should().Be("Invalid content release");
        problem.Detail.Should().Be("Certification catalog is invalid.");
    }

    [Fact]
    public async Task AuthFailedException_MapsTo401_ProblemDetails()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context, _ => throw new AuthFailedException("Identifiants invalides."));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Unauthorized);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(401);
        problem.Title.Should().Be("Unauthorized");
        problem.Detail.Should().Be("Identifiants invalides.");
    }

    [Fact]
    public async Task RateLimitedException_MapsTo429_ProblemDetails()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context, _ => throw new RateLimitedException("Trop de tentatives."));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.TooManyRequests);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(429);
        problem.Title.Should().Be("Too Many Requests");
        problem.Detail.Should().Be("Trop de tentatives.");
    }

    [Fact]
    public async Task AccountDeletionInProgressException_MapsTo423_ProblemDetails()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(
            invocation.Context,
            _ => throw new AccountDeletionInProgressException());

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be((HttpStatusCode)423);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(423);
        problem.Title.Should().Be("Account deletion in progress");
        problem.Detail.Should().NotContain("Cosmos");
    }

    [Fact]
    public async Task AccountDeletionDisabledException_MapsTo503_ProblemDetails()
    {
        var logger = new CapturingLogger();
        var middleware = new ExceptionMiddleware(logger);
        var invocation = FunctionTestHarness.CreateHttp();
        var exception = new AccountDeletionDisabledException();

        await middleware.Invoke(
            invocation.Context,
            _ => throw exception);

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(503);
        problem.Title.Should().Be("Account deletion unavailable");
        var entry = logger.Entries.Should().ContainSingle().Subject;
        entry.Level.Should().Be(LogLevel.Warning);
        entry.Exception.Should().BeSameAs(exception);
        entry.Properties["FunctionName"].Should().Be(invocation.Context.FunctionDefinition.Name);
        entry.Properties["InvocationId"].Should().Be(invocation.Context.InvocationId);
        entry.Properties["{OriginalFormat}"].Should().Be(
            "Account deletion is disabled in function {FunctionName}, invocation {InvocationId}.");
    }

    [Fact]
    public async Task UnexpectedException_DoesNotEmitDisabledAccountDeletionMarker()
    {
        var logger = new CapturingLogger();
        var middleware = new ExceptionMiddleware(logger);
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context, _ => throw new InvalidOperationException("failure"));

        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.InternalServerError);
        logger.Entries.Should().ContainSingle()
            .Which.Level.Should().Be(LogLevel.Error);
        logger.Entries.Should().NotContain(entry => entry.Exception is AccountDeletionDisabledException);
    }

    private sealed class CapturingLogger : ILogger<ExceptionMiddleware>
    {
        public List<(LogLevel Level, Exception? Exception, Dictionary<string, object?> Properties)> Entries { get; } = [];

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state,
            Exception? exception, Func<TState, Exception?, string> formatter)
        {
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values.ToDictionary(pair => pair.Key, pair => pair.Value)
                : new Dictionary<string, object?>();
            Entries.Add((logLevel, exception, properties));
        }
    }

    [Fact]
    public async Task DuplicateRecordException_MapsTo409_WithExceptionMessage()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context, _ => throw new DuplicateRecordException("Cet e-mail est déjà utilisé."));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Conflict);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(409);
        problem.Title.Should().Be("Conflict");
        problem.Detail.Should().Be("Cet e-mail est déjà utilisé.");
    }

    [Fact]
    public async Task ConcurrencyConflictException_MapsTo409_WithGenericDetail_AndDoesNotLeakInternals()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context,
            _ => throw new ConcurrencyConflictException("ETag 42 mismatch on document quiz-attempt-abc"));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Conflict);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(409);
        problem.Title.Should().Be("Conflict");
        // The raw message (ETag/document id) must NOT reach the client — only a safe, generic detail.
        problem.Detail.Should().Be("The request conflicted with a concurrent update; please retry.");
        problem.Detail.Should().NotContain("ETag");
        problem.Detail.Should().NotContain("quiz-attempt-abc");
    }

    [Fact]
    public async Task GenericException_MapsTo500_WithSafeDetail_AndDoesNotLeakInternals()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context,
            _ => throw new InvalidOperationException("secret connection string in stack trace"));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.InternalServerError);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(500);
        problem.Title.Should().Be("Unexpected server error");
        problem.Detail.Should().Be("Certigo could not complete the request.");
        problem.Detail.Should().NotContain("secret");
    }

    [Fact]
    public async Task InboundCorrelationId_IsHonoured_OnResponseHeaderAndBody()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp(
            headers: new Dictionary<string, string> { ["x-correlation-id"] = "trace-abc-123" });

        await middleware.Invoke(invocation.Context, _ => throw new BadRequestException("bad"));

        invocation.CorrelationId.Should().Be("trace-abc-123");
        invocation.Context.Items["CorrelationId"].Should().Be("trace-abc-123");

        var problem = await invocation.ReadProblemAsync();
        problem!.CorrelationId.Should().Be("trace-abc-123");
    }

    [Fact]
    public async Task CorrelationId_IsGenerated_WhenInboundHeaderAbsent()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context, _ => throw new BadRequestException("bad"));

        invocation.CorrelationId.Should().NotBeNullOrWhiteSpace();
        invocation.CorrelationId.Should().MatchRegex("^[0-9a-f]{32}$");

        var problem = await invocation.ReadProblemAsync();
        problem!.CorrelationId.Should().Be(invocation.CorrelationId);
        invocation.Context.Items["CorrelationId"].Should().Be(invocation.CorrelationId);
    }

    [Fact]
    public async Task SuccessfulInvocation_WritesNoErrorResponse_ButStampsCorrelationId()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
        invocation.Response.Should().BeNull();
        invocation.Context.Items.Should().ContainKey("CorrelationId");
        invocation.Context.Items["CorrelationId"].Should().BeOfType<string>()
            .Which.Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public async Task NonHttpTrigger_GenericException_IsRethrown_AndNoResponseWritten()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateNonHttp();
        var boom = new InvalidOperationException("downstream failure");

        Func<Task> act = () => middleware.Invoke(invocation.Context, _ => throw boom);

        (await act.Should().ThrowAsync<InvalidOperationException>())
            .WithMessage("downstream failure");
        invocation.Response.Should().BeNull();
        invocation.Context.Items["CorrelationId"].Should().BeOfType<string>();
    }
}
