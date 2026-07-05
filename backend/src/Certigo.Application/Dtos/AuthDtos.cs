namespace Certigo.Application.Dtos;

// --- Email/password authentication -----------------------------------------

public sealed record RegisterRequest(string Email, string Password, string? DisplayName = null);

public sealed record LoginRequest(string Email, string Password);

public sealed record RefreshTokenRequest(string RefreshToken);

/// Body of POST /auth/resend-verification. Anonymous; always answered generically.
public sealed record ResendVerificationRequest(string Email);

/// The payload returned by register/login/refresh: the freshly-minted token pair
/// plus the learner's (provisioned) profile so the client can render the home
/// screen without a second round-trip. <see cref="EmailVerified"/> lets the app
/// surface a soft "confirm your email" banner; it is <c>true</c> for social/Entra
/// sessions and grandfathered accounts (never blocking), <c>false</c> only for a
/// freshly-registered email/password account awaiting confirmation.
public sealed record AuthResultDto(
    string AccessToken,
    string RefreshToken,
    DateTimeOffset AccessTokenExpiresAt,
    UserProfileDto Profile,
    bool EmailVerified = true);
