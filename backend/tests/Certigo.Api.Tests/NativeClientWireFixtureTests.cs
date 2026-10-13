using System.Net;
using System.Text.Json.Nodes;
using Certigo.Api.Functions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using FluentAssertions;
using Microsoft.Azure.Functions.Worker.Http;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class NativeClientWireFixtureTests
{
    private const string ManifestId =
        "sha256:0000000000000000000000000000000000000000000000000000000000000000";

    [Fact]
    public async Task Catalog_function_emits_the_shared_native_wire_fixture()
    {
        var service = new FakeContentService
        {
            CatalogResult = new CatalogDto(
                CertificationCatalogSchemas.AppV2,
                CertificationCatalogSchemas.SourceV1,
                new DateOnly(2026, 10, 1),
                new CatalogFreshnessDto(30, new DateOnly(2026, 10, 31)),
                [],
                [new TrackSummaryDto(
                    "demo-track", "CG-DEMO", "Synthetic certification", "Fundamentals",
                    "Public API contract fixture, not an authored certification.", 1, 1,
                    [new CertificationDomainDto("demo-domain", "Demo domain", 100, 100)])]),
        };
        var context = TestFunctionContext.Authenticated();
        var response = await new CatalogFunctions(service).GetCatalog(
            new TestHttpRequestData(context, "GET", "https://localhost/api/catalog/tracks"),
            context);

        await AssertFixtureAsync(response, "catalog.json");
    }

    [Fact]
    public async Task Path_function_emits_the_shared_native_wire_fixture()
    {
        var service = new FakePathService
        {
            Result = new PathDto(
                "demo-track", "Synthetic certification", "CG-DEMO", 42, -2,
                [new PathUnitDto(
                    "demo-unit", "Demo unit", "demo-domain", "active",
                    [new PathLessonDto("demo-lesson", "Demo lesson", "available", 5, 20)])],
                [new DomainProgressDto("demo-domain", "Demo domain", 1, 42)]),
        };
        var context = TestFunctionContext.Authenticated();
        var response = await new PathFunctions(service).GetMyPath(
            new TestHttpRequestData(context, "GET", "https://localhost/api/me/paths/demo-track"),
            "demo-track",
            context);

        await AssertFixtureAsync(response, "path.json");
    }

    [Fact]
    public async Task Public_lesson_emits_optional_checks_and_exact_manifest_headers()
    {
        var service = new FakeContentService
        {
            PublicManifestId = ManifestId,
            LessonResult = new Lesson(
                "demo-lesson", "demo-track", "demo-unit", "demo-domain", "Demo lesson", 5,
                [
                    new LessonBlock(
                        "concept", "demo-concept", "Public synthetic content",
                        "This fixture contains no answer key."),
                    new LessonBlock(
                        "check", "demo-concept", Check: new LessonCheck(
                            "demo-item", "demo-concept", ItemType.Mcq, "Choose an option.",
                            [new CheckOption("a", "Option A"), new CheckOption("b", "Option B")])),
                    new LessonBlock(
                        "check", "demo-concept", Check: new LessonCheck(
                            "demo-pairs", "demo-concept", ItemType.MatchPairs, "Match the labels.",
                            [new CheckOption("left-1", "Left label")],
                            [new CheckOption("right-1", "Right label")])),
                ]),
        };
        var context = TestFunctionContext.Authenticated();
        var response = await new LessonFunctions(service).GetLesson(
            new TestHttpRequestData(
                context, "GET", "https://localhost/api/tracks/demo-track/lessons/demo-lesson"),
            "demo-track",
            "demo-lesson",
            context);

        await AssertFixtureAsync(response, "lesson.json");
        response.Headers.GetValues("X-Content-Manifest-Id").Should().Equal(ManifestId);
        response.Headers.GetValues("ETag").Should().Equal($"\"{ManifestId}\"");
        var publicJson = JsonNode.Parse(ReadFixture("lesson.json"))!;
        publicJson["blocks"]![1]!["check"]!.AsObject().ContainsKey("matches").Should().BeFalse();
        publicJson["blocks"]![2]!["check"]!.AsObject().ContainsKey("matches").Should().BeTrue();
        RequireAnswerFree(publicJson);
    }

    [Theory]
    [InlineData(false, "quiz-submit-result.json")]
    [InlineData(true, "quiz-submit-correct-result.json")]
    public async Task Quiz_function_reads_the_shared_request_and_emits_post_submission_feedback(
        bool correct,
        string fixtureName)
    {
        var result = new SubmitQuizResult(
            correct ? "demo-correct-attempt" : "demo-attempt", correct ? 100 : 0,
            [new ItemResultDto(
                "demo-item", correct, "demo-concept", correct ? null : ["a"],
                "Synthetic feedback returned only after submission.", correct ? 0.05 : -0.05)],
            new RewardsDto(correct ? 10 : 0, correct ? 110 : 100, false, false, correct ? 6 : 0, []),
            correct ? [] : ["demo-concept"],
            correct ? null : new DateTimeOffset(2026, 10, 2, 12, 0, 0, TimeSpan.Zero));
        var service = new FakeQuizService { Result = result };
        var context = TestFunctionContext.Authenticated();
        var requestBody = JsonNode.Parse(ReadFixture("quiz-submit-request.json"))!;
        var response = await new QuizFunctions(service).SubmitQuiz(
            new TestHttpRequestData(
                context, "POST", "https://localhost/api/quiz/demo-lesson/submit", requestBody),
            "demo-lesson",
            context);

        service.LastLessonId.Should().Be("demo-lesson");
        service.LastRequest.Should().BeEquivalentTo(new SubmitQuizRequest(
            "demo-client-attempt", "demo-track",
            new DateTimeOffset(2026, 10, 1, 12, 0, 0, TimeSpan.Zero),
            [new AnswerDto("demo-item", ItemType.Mcq, ["b"], 4200)],
            ManifestId));
        await AssertFixtureAsync(response, fixtureName);
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

    private static void RequireAnswerFree(JsonNode node)
    {
        if (node is JsonObject jsonObject)
        {
            foreach (var property in jsonObject)
            {
                new[] { "correct", "correctAnswer", "answerKey", "privateManifestId", "explanation" }
                    .Should().NotContain(property.Key);
                if (property.Value is not null)
                {
                    RequireAnswerFree(property.Value);
                }
            }
        }
        else if (node is JsonArray jsonArray)
        {
            foreach (var child in jsonArray)
            {
                if (child is not null)
                {
                    RequireAnswerFree(child);
                }
            }
        }
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
