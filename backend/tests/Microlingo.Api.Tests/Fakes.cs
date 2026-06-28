using System.Security.Claims;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Tests;

// Hand-rolled doubles for the application abstractions the HTTP layer depends on.
// Following the convention of Microlingo.Application.Tests: no mocking library, fakes are
// `internal sealed`, and they capture call arguments / counts as public properties so the
// tests can assert on what the middleware and functions forwarded.

/// <summary>Configurable <see cref="ITokenValidator"/> that returns a preset result and records the token it saw.</summary>
internal sealed class FakeTokenValidator : ITokenValidator
{
    public TokenValidationResult Result { get; set; } = new(false, null, null);

    public string? LastToken { get; private set; }

    public int CallCount { get; private set; }

    public static FakeTokenValidator Succeeding(ClaimsPrincipal principal, string? userId = null) =>
        new() { Result = new TokenValidationResult(true, principal, userId) };

    public static FakeTokenValidator Failing() =>
        new() { Result = new TokenValidationResult(false, null, null) };

    public Task<TokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default)
    {
        LastToken = token;
        CallCount++;
        return Task.FromResult(Result);
    }
}

/// <summary>Captures the requests forwarded to <see cref="IAuthService"/> and returns a canned result.</summary>
internal sealed class FakeAuthService : IAuthService
{
    public AuthResultDto Result { get; set; } = DefaultResult();

    public RegisterRequest? LastRegister { get; private set; }

    public LoginRequest? LastLogin { get; private set; }

    public RefreshTokenRequest? LastRefresh { get; private set; }

    public int RegisterCallCount { get; private set; }

    public int LoginCallCount { get; private set; }

    public int RefreshCallCount { get; private set; }

    public Task<AuthResultDto> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
    {
        LastRegister = request;
        RegisterCallCount++;
        return Task.FromResult(Result);
    }

    public Task<AuthResultDto> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        LastLogin = request;
        LoginCallCount++;
        return Task.FromResult(Result);
    }

    public Task<AuthResultDto> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken = default)
    {
        LastRefresh = request;
        RefreshCallCount++;
        return Task.FromResult(Result);
    }

    private static AuthResultDto DefaultResult() =>
        new(
            "access-token",
            "refresh-token",
            DateTimeOffset.UtcNow.AddHours(1),
            new UserProfileDto("user-1", "Test User", "testuser", null, 0, 1, 0, 0, 50, 0, 0, null));
}

/// <summary>Captures the lesson id + request forwarded to <see cref="IQuizService"/> and returns a canned result.</summary>
internal sealed class FakeQuizService : IQuizService
{
    public SubmitQuizResult Result { get; set; } = DefaultResult();

    public string? LastLessonId { get; private set; }

    public SubmitQuizRequest? LastRequest { get; private set; }

    public int CallCount { get; private set; }

    public Task<SubmitQuizResult> SubmitAsync(string lessonId, SubmitQuizRequest request, CancellationToken cancellationToken = default)
    {
        LastLessonId = lessonId;
        LastRequest = request;
        CallCount++;
        return Task.FromResult(Result);
    }

    private static SubmitQuizResult DefaultResult() =>
        new(
            "attempt-1",
            100,
            new List<ItemResultDto>(),
            new RewardsDto(10, 10, false, false, 0, new List<string>()),
            new List<string>(),
            null);
}
