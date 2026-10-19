using System.Net;
using System.Text.Json.Nodes;
using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using FluentAssertions;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class NativeClientWireFixtureTests
{
    [Fact]
    public async Task Active_goal_function_consumes_the_shared_request_and_emits_the_owner_profile()
    {
        var service = new FakeUserService
        {
            Result = new UserProfileDto(
                "demo-owner", "Synthetic learner", "demo-learner", null,
                100, 1, 0, 0, 50, 0, 0, null,
                EconomyReceipts:
                [
                    new EconomyProfileReceipt(
                        "synthetic-internal-operation", DateTimeOffset.UnixEpoch, "{}"),
                ],
                AppliedEconomyOperations: ["synthetic-legacy-operation"]),
        };
        var context = TestFunctionContext.Authenticated();
        var response = await new UserFunctions(service).SetActiveTrack(
            new TestHttpRequestData(
                context, "POST", "https://localhost/api/me/active-track",
                JsonNode.Parse(ReadFixture("active-track-request.json"))!),
            context);

        service.LastTrackId.Should().Be("demo-track");
        service.LastExpectedTrackId.Should().BeNull();
        await AssertFixtureAsync(response, "profile.json");
        var reloaded = await new UserFunctions(service).GetMe(
            new TestHttpRequestData(context, "GET", "https://localhost/api/me"), context);
        await AssertFixtureAsync(reloaded, "profile.json");
    }

    [Theory]
    [InlineData(false, 409, "Active track conflict")]
    [InlineData(true, 404, "Track not found")]
    public async Task Active_goal_errors_have_the_existing_problem_status(
        bool missingTrack, int status, string title)
    {
        var invocation = FunctionTestHarness.CreateHttp();
        var middleware = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        Exception error = missingTrack
            ? new TrackNotFoundException("unavailable-track")
            : new ActiveTrackConflictException();

        await middleware.Invoke(invocation.Context, _ => throw error);

        invocation.Response!.StatusCode.Should().Be((HttpStatusCode)status);
        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(status);
        problem.Title.Should().Be(title);
    }

    private static async Task AssertFixtureAsync(HttpResponseData response, string fileName)
    {
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Headers.GetValues("Content-Type").Should()
            .Equal("application/json; charset=utf-8");
        var actual = JsonNode.Parse(await response.ReadBodyAsStringAsync());
        var expected = JsonNode.Parse(ReadFixture(fileName));
        JsonNode.DeepEquals(actual, expected).Should().BeTrue(
            $"{fileName} must remain faithful to the existing HTTP serializer");
    }

    private static string ReadFixture(string fileName)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(
                directory.FullName, "docs", "contracts", "native-client", "v1", fileName);
            if (File.Exists(candidate))
            {
                return File.ReadAllText(candidate);
            }
            directory = directory.Parent;
        }
        throw new FileNotFoundException($"Native client fixture {fileName} was not found.");
    }
}
