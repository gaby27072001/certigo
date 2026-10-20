using System.Net;
using System.Text.Json;
using FluentAssertions;
using Certigo.Api.Auth;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class LearningFunctionsTests
{
    [Fact]
    public async Task GetMyHistory_ReturnsBoundedSummaryContract_WithoutPrivateResultFields()
    {
        var service = new FakeHistoryService();
        var function = new LearningFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/me/history?limit=2&cursor=opaque");

        var response = await function.GetMyHistory(request, context);
        var body = await response.ReadBodyAsStringAsync();
        using var document = JsonDocument.Parse(body);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Headers.GetValues("Cache-Control").Should().ContainSingle().Which.Should()
            .Be("no-store");
        service.LastLimit.Should().Be(2);
        service.LastCursor.Should().Be("opaque");
        var root = document.RootElement;
        root.EnumerateObject().Select(property => property.Name)
            .Should().BeEquivalentTo("items", "nextCursor");
        var item = root.GetProperty("items")[0];
        item.EnumerateObject().Select(property => property.Name).Should().BeEquivalentTo(
            "kind", "attemptId", "clientAttemptId", "trackId", "lessonId", "submittedAt",
            "scorePct", "answeredCount", "correctCount", "xpEarned", "gemsEarned",
            "publicManifestId");
        body.Should().NotContain("correctAnswer");
        body.Should().NotContain("explanation");
        body.Should().NotContain("weakConcepts");
        body.Should().NotContain("userId");
    }

    [Theory]
    [InlineData("/api/me/history?limit=0")]
    [InlineData("/api/me/history?limit=51")]
    [InlineData("/api/me/history?limit=20&userId=other-user")]
    [InlineData("/api/me/history?limit=20&cursor=bad&cursor=duplicate")]
    public async Task InvalidHistoryQuery_Returns400_ThroughProductionMiddleware(string path)
    {
        var service = new FakeHistoryService();
        var function = new LearningFunctions(service);
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        var validator = FakeTokenValidator.Succeeding(TestPrincipal.With(oid: "user-1"), "user-1");
        var jwt = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "GET",
            path: path,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer valid-token" });

        await exception.Invoke(invocation.Context, context => jwt.Invoke(context, async inner =>
        {
            var request = await inner.GetHttpRequestDataAsync()
                ?? throw new InvalidOperationException("HTTP request missing.");
            var response = await function.GetMyHistory(request, inner);
            inner.GetInvocationResult().Value = response;
        }));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        service.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task HistoryRoute_RequiresBearerAuthentication()
    {
        var validator = FakeTokenValidator.Failing();
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "GET",
            path: "/api/me/history");

        await middleware.Invoke(invocation.Context, _ => Task.CompletedTask);

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        validator.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task HistoryRoute_RespectsAccountDeletionLock()
    {
        var validator = FakeTokenValidator.Succeeding(TestPrincipal.With(oid: "user-1"), "user-1");
        var middleware = new JwtAuthMiddleware(validator, new LockedHistoryGuard());
        var invocation = FunctionTestHarness.CreateHttp(
            method: "GET",
            path: "/api/me/history",
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer valid-token" });

        await middleware.Invoke(invocation.Context, _ => Task.CompletedTask);

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be((HttpStatusCode)423);
    }

    private sealed class FakeHistoryService : IAttemptHistoryService
    {
        public int? LastLimit { get; private set; }
        public string? LastCursor { get; private set; }
        public int CallCount { get; private set; }

        public Task<AttemptHistoryPageDto> GetPageAsync(
            int limit,
            string? cursor,
            CancellationToken cancellationToken = default)
        {
            LastLimit = limit;
            LastCursor = cursor;
            CallCount++;
            return Task.FromResult(new AttemptHistoryPageDto(
                [
                    new AttemptHistorySummaryDto(
                        "quiz", "result-1", "client-1", "track-1", "lesson-1",
                        DateTimeOffset.UnixEpoch, 80, 5, 4, 25, 0, null),
                ],
                null));
        }
    }

    private sealed class LockedHistoryGuard : IAccountDeletionAccessGuard
    {
        public Task<bool> IsBlockedAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(true);
    }
}
