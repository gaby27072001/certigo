namespace Microlingo.Application.Abstractions;

/// Raised when an email/password authentication attempt fails (unknown email,
/// wrong password, or an expired/invalid refresh token). Mapped to 401 by the
/// API so the client can prompt the learner to retry or sign up. The message is
/// deliberately generic on the login path so it never reveals whether an email
/// is registered.
public sealed class AuthFailedException(string message) : Exception(message);

/// Raised when an account is temporarily locked after too many failed logins.
/// Mapped to HTTP 429 (Too Many Requests) so the client can surface a distinct
/// "try again later" message and back off.
public sealed class RateLimitedException(string message) : Exception(message);

/// One stored email/password credential. Lives in the Users container in its own
/// partition (id = <c>credential::{emailLower}</c>, which is also the partition
/// key) so it never collides with a profile document (whose id is the userId).
/// The password is never stored in clear text — only the PBKDF2 hash string.
public sealed record UserCredentialRecord(
    string Id,
    string Email,
    string UserId,
    string DisplayName,
    string PasswordHash,
    DateTimeOffset CreatedAt,
    int FailedAttempts = 0,
    DateTimeOffset? LockoutUntil = null)
{
    /// Discriminator persisted alongside the document; combined with the id
    /// prefix it keeps credential docs unambiguously separate from profiles.
    public string Type => "credential";

    /// The canonical Cosmos id (and partition key) for a credential, derived from
    /// the already-normalised (trimmed, lower-cased) email.
    public static string IdFor(string emailLower) => $"credential::{emailLower}";
}

/// Persists and looks up email/password credentials. Backed by the Users
/// container so no new Cosmos container or Bicep change is required.
public interface IUserCredentialRepository
{
    Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default);

    /// Atomically creates the credential. Throws <see cref="DuplicateRecordException"/>
    /// when a credential for the same email already exists (turns the legacy
    /// check-then-create race into a single guarded write).
    Task CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default);

    /// Replaces an existing credential document (used to update the failed-login
    /// counter and lockout window). Last-writer-wins, which is acceptable for a
    /// best-effort brute-force counter.
    Task UpdateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default);
}

/// One-way password hashing. The implementation is a salted, iterated KDF; verify
/// must be constant-time to avoid leaking the hash through timing.
public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}

/// Mints the locally-issued JWTs that back email/password sessions. Access tokens
/// are accepted by the API's token validator alongside Entra tokens; refresh
/// tokens are only honoured here to re-issue an access token.
public interface ITokenIssuer
{
    IssuedTokens Issue(string userId, string displayName, string email);

    /// Validates a refresh token (signature, lifetime, and the refresh marker)
    /// and returns the carried principal, or <see langword="null"/> when invalid.
    RefreshTokenPrincipal? ValidateRefreshToken(string refreshToken);
}

public sealed record IssuedTokens(string AccessToken, string RefreshToken, DateTimeOffset AccessTokenExpiresAt);

public sealed record RefreshTokenPrincipal(string UserId, string DisplayName, string Email);
