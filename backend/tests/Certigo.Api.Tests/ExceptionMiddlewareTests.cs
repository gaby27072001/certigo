using System.Net;
using FluentAssertions;
using Certigo.Api.Http;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
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
