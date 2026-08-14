using System.Net;
using System.Text.Json;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class CriticalHttpFunctionsTests
{
    [Fact]
    public async Task Catalog_requires_an_authenticated_user()
    {
        var function = new CatalogFunctions(new FakeContentService());
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/catalog/tracks");

        var act = () => function.GetCatalog(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
    }

    [Fact]
    public async Task Catalog_returns_the_serialized_track_picker_payload()
    {
        var service = new FakeContentService
        {
            Catalog = new CatalogDto(
                new[]
                {
                    new TrackSummaryDto("track-1", "AZ-900", "Azure Fundamentals", "Fundamentals", "Intro", 3, 12),
                }),
        };
        var function = new CatalogFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/catalog/tracks");

        var response = await function.GetCatalog(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.GetCatalogCalls.Should().Be(1);
        var payload = await response.ReadJsonAsync<CatalogDto>();
        payload.Tracks.Should().ContainSingle();
        payload.Tracks[0].Code.Should().Be("AZ-900");
    }

    [Fact]
    public async Task SubmitQuiz_reads_the_json_body_and_passes_it_to_the_service()
    {
        var expected = new SubmitQuizResult(
            "attempt-1",
            100,
            new List<ItemResultDto>
            {
                new("item-1", true, "concept-1", null, "Bien vu", 0.2),
            },
            new RewardsDto(10, 110, false, false, 2, new List<string>()),
            new List<string>(),
            new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var service = new FakeQuizService { Result = expected };
        var function = new QuizFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var requestBody = new SubmitQuizRequest(
            "client-attempt-1",
            "track-1",
            new DateTimeOffset(2025, 1, 6, 11, 58, 0, TimeSpan.Zero),
            new List<AnswerDto> { new("item-1", ItemType.Mcq, new List<string> { "a" }, 4200) });
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/quiz/lesson-1/submit",
            requestBody);

        var response = await function.SubmitQuiz(request, "lesson-1", context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.LastLessonId.Should().Be("lesson-1");
        service.LastRequest.Should().NotBeNull();
        service.LastRequest!.TrackId.Should().Be("track-1");
        service.LastRequest.ClientAttemptId.Should().Be("client-attempt-1");
        service.LastRequest.Answers.Should().ContainSingle(a => a.ItemId == "item-1");
        var payload = await response.ReadJsonAsync<SubmitQuizResult>();
        payload.AttemptId.Should().Be(expected.AttemptId);
        payload.ScorePct.Should().Be(100);
    }

    [Fact]
    public async Task SubmitQuiz_requires_an_authenticated_user()
    {
        var function = new QuizFunctions(new FakeQuizService());
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/quiz/lesson-1/submit",
            new SubmitQuizRequest(
                "client-attempt-1",
                "track-1",
                new DateTimeOffset(2025, 1, 6, 11, 58, 0, TimeSpan.Zero),
                new List<AnswerDto>()));

        var act = () => function.SubmitQuiz(request, "lesson-1", context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
    }

    [Fact]
    public async Task Register_accepts_an_anonymous_request_and_returns_created()
    {
        var expected = AuthResult("alice@example.com");
        expected = expected with
        {
            Profile = expected.Profile with
            {
                EconomyReceipts =
                [
                    new EconomyProfileReceipt(
                        "operation::quiz::internal",
                        DateTimeOffset.UtcNow,
                        "{\"xpEarned\":10}"),
                ],
                AppliedEconomyOperations = ["operation::quiz::legacy"],
            },
        };
        var service = new FakeAuthService { RegisterResult = expected };
        var function = new AuthFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/auth/register",
            new RegisterRequest("alice@example.com", "password123", "Alice"));

        var response = await function.Register(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        service.RegisterCalls.Should().ContainSingle();
        service.RegisterCalls[0].Email.Should().Be("alice@example.com");
        var rawPayload = await response.ReadBodyAsStringAsync();
        rawPayload.Should().NotContain("economyReceipts");
        rawPayload.Should().NotContain("appliedEconomyOperations");
        var payload = JsonSerializer.Deserialize<AuthResultDto>(
            rawPayload,
            new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        payload.AccessToken.Should().Be(expected.AccessToken);
        payload.Profile.DisplayName.Should().Be("Alice");
    }

    [Fact]
    public async Task Login_rejects_missing_credentials_with_a_bad_request()
    {
        var function = new AuthFunctions(new FakeAuthService());
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/auth/login",
            new LoginRequest(string.Empty, string.Empty));

        var act = () => function.Login(request, context);

        var error = await Assert.ThrowsAsync<BadRequestException>(act);
        error.Message.Should().Be("E-mail et mot de passe sont requis.");
    }

    [Fact]
    public async Task Register_rejects_an_invalid_email_with_a_bad_request()
    {
        var function = new AuthFunctions(new FakeAuthService());
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/auth/register",
            new RegisterRequest("not-an-email", "password123"));

        var act = () => function.Register(request, context);

        var error = await Assert.ThrowsAsync<BadRequestException>(act);
        error.Message.Should().Be("Adresse e-mail invalide.");
    }

    private static AuthResultDto AuthResult(string email)
        => new(
            "access-token",
            "refresh-token",
            new DateTimeOffset(2025, 1, 6, 13, 0, 0, TimeSpan.Zero),
            new UserProfileDto("user-1", "Alice", "alice", null, 100, 2, 3, 0, 50, 10, 25, "track-1"));

    private sealed class FakeContentService : IContentService
    {
        public CatalogDto Catalog { get; set; } = new(Array.Empty<TrackSummaryDto>());
        public int GetCatalogCalls { get; private set; }

        public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
            => Task.FromResult<Lesson?>(null);

        public Task<CatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default)
        {
            GetCatalogCalls++;
            return Task.FromResult(Catalog);
        }
    }

    private sealed class FakeQuizService : IQuizService
    {
        public SubmitQuizResult Result { get; set; } = new(
            "attempt-default",
            0,
            new List<ItemResultDto>(),
            new RewardsDto(0, 0, false, false, 0, new List<string>()),
            new List<string>(),
            null);

        public string? LastLessonId { get; private set; }
        public SubmitQuizRequest? LastRequest { get; private set; }

        public Task<SubmitQuizResult> SubmitAsync(
            string lessonId,
            SubmitQuizRequest request,
            CancellationToken cancellationToken = default)
        {
            LastLessonId = lessonId;
            LastRequest = request;
            return Task.FromResult(Result);
        }
    }

    private sealed class FakeAuthService : IAuthService
    {
        public AuthResultDto RegisterResult { get; set; } = AuthResult("user@example.com");
        public List<RegisterRequest> RegisterCalls { get; } = new();

        public Task<AuthResultDto> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
        {
            RegisterCalls.Add(request);
            return Task.FromResult(RegisterResult);
        }

        public Task<AuthResultDto> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
            => Task.FromResult(RegisterResult);

        public Task<AuthResultDto> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken = default)
            => Task.FromResult(RegisterResult);
    }
}
