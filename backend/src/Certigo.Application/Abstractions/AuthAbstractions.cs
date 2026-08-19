using System.Text.Json.Serialization;

namespace Certigo.Application.Abstractions;

/// Raised when persistence rejects a write before it can commit. Callers may
/// safely roll back a reservation; transport/time-out failures must not use it.
public sealed class DefinitivePersistenceException(string message, Exception innerException)
    : Exception(message, innerException);

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

public enum CredentialProvisioningState
{
    Pending,
    Active,
}

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
    DateTimeOffset? LockoutUntil = null,
    // Provider-canonical form of the email (e.g. Gmail: dots stripped, "+tag"
    // dropped, googlemail.com -> gmail.com). Used at registration to reject a
    // second account that maps to the same real mailbox. Null on pre-feature
    // documents (they were created before canonicalisation existed).
    string? CanonicalEmail = null,
    // Tri-state email-ownership flag. null = grandfathered (created before email
    // verification shipped; treated as verified so existing users are never
    // nagged or blocked); false = registered but not yet confirmed; true =
    // confirmed via the emailed link. See <see cref="IsEmailVerified"/>.
    bool? EmailVerified = null,
    // SHA-256 (Base64) hash of the outstanding verification token — never the raw
    // token — so a database reader cannot harvest a live confirmation link.
    string? VerificationTokenHash = null,
    DateTimeOffset? VerificationTokenExpiresAt = null,
    // Null means active for credentials created before atomic canonical
    // reservations shipped. New registrations stay pending until their profile
    // has been provisioned, which makes an interrupted sign-up recoverable.
    CredentialProvisioningState? ProvisioningState = null,
    DateTimeOffset? ProvisioningLeaseExpiresAt = null)
{
    /// Discriminator persisted alongside the document; combined with the id
    /// prefix it keeps credential docs unambiguously separate from profiles.
    public string Type => "credential";

    /// The canonical Cosmos id (and partition key) for a credential, derived from
    /// the already-normalised (trimmed, lower-cased) email.
    public static string IdFor(string emailLower) => $"credential::{emailLower}";

    /// Canonical reservation id. All provider aliases for one mailbox map to the
    /// same Cosmos id/partition key, so CreateItem is the uniqueness arbiter.
    public static string CanonicalIdFor(string canonicalEmail) => $"credential::canonical::{canonicalEmail}";

    /// Whether the account counts as verified. A grandfathered credential (null
    /// flag) is treated as verified so pre-feature accounts keep working; only an
    /// explicit <c>false</c> means "pending confirmation". Never persisted (it is
    /// derived), so it can't drift from <see cref="EmailVerified"/>.
    [JsonIgnore]
    public bool IsEmailVerified => EmailVerified != false;

    [JsonIgnore]
    public bool IsProvisioning => ProvisioningState == CredentialProvisioningState.Pending;

    /// Cosmos optimistic-concurrency token (`_etag`). Populated on reads and used
    /// on updates to prevent concurrent lockout/password state from being
    /// overwritten by stale writers.
    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }
}

/// Persists and looks up email/password credentials. Backed by the Users
/// container so no new Cosmos container or Bicep change is required.
public interface IUserCredentialRepository
{
    Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default);

    /// Finds a credential by its provider-canonical email (see
    /// <see cref="AuthRules.CanonicalizeEmail"/>). Used to reject a second
    /// registration that maps to the same real mailbox (e.g. Gmail dot/"+tag"
    /// variants), and as a login fallback so a learner who types a different dot
    /// variant of their own address is still matched. Cross-partition query, but
    /// only hit on the (rare) register path and login misses. Returns null on
    /// pre-feature documents, which carry no canonical email.
    Task<UserCredentialRecord?> FindByCanonicalEmailAsync(string canonicalEmail, CancellationToken cancellationToken = default);

    /// Atomically creates the credential. Throws <see cref="DuplicateRecordException"/>
    /// when a credential for the same email already exists (turns the legacy
    /// check-then-create race into a single guarded write).
    Task<UserCredentialRecord> CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default);

    /// Replaces an existing credential document (used to update the failed-login
    /// counter, lockout window, and password hash) using optimistic concurrency.
    Task UpdateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default);

    /// Conditionally removes an incomplete reservation. A concurrent recovery
    /// that advanced the ETag wins and leaves the reservation in place.
    Task<bool> DeletePendingAsync(UserCredentialRecord record, CancellationToken cancellationToken = default);
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
    IssuedTokens Issue(
        string userId,
        string displayName,
        string email,
        DateTimeOffset? authenticatedAt = null);

    /// Validates a refresh token (signature, lifetime, and the refresh marker)
    /// and returns the carried principal, or <see langword="null"/> when invalid.
    RefreshTokenPrincipal? ValidateRefreshToken(string refreshToken);
}

public sealed record IssuedTokens(string AccessToken, string RefreshToken, DateTimeOffset AccessTokenExpiresAt);

public sealed record RefreshTokenPrincipal(
    string UserId,
    string DisplayName,
    string Email,
    DateTimeOffset AuthenticatedAt);

// --- Email delivery + verification ----------------------------------------

/// A transactional email ready to hand to a provider. Kept provider-agnostic so
/// the application layer never references a concrete SDK; the Infrastructure
/// layer adapts it (Azure Communication Services in production, a logging no-op
/// when no provider is configured).
public sealed record EmailMessage(
    string ToEmail,
    string? ToName,
    string Subject,
    string HtmlBody,
    string PlainTextBody);

/// Sends transactional email. The production binding is Azure Communication
/// Services; when no provider is configured the binding is a logging no-op, so
/// the whole register/verify flow still works end-to-end (the confirmation link
/// is written to the logs) without blocking sign-up.
public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default);
}

/// Configuration for the email-verification link and token lifetime, supplied
/// from app settings (see Program.cs). <see cref="VerifyBaseUrl"/> is the public
/// URL of the GET verify endpoint (e.g. https://host/api/auth/verify-email); the
/// service appends <c>?code=…</c>.
public sealed record AuthEmailOptions(string VerifyBaseUrl, TimeSpan TokenLifetime)
{
    public static AuthEmailOptions Default { get; } = new(string.Empty, TimeSpan.FromHours(24));
}

/// Confirms an email address from the code carried by the verification link, and
/// resends a confirmation email on demand. Kept separate from
/// <see cref="IAuthService"/> so the token-issuing surface stays small and the
/// existing auth fakes are unaffected.
public interface IEmailVerificationService
{
    Task<EmailVerificationResult> VerifyAsync(string code, CancellationToken cancellationToken = default);

    /// Best-effort resend. Always completes without revealing whether the address
    /// exists or is already verified (no account enumeration).
    Task ResendAsync(string email, CancellationToken cancellationToken = default);
}

public sealed record EmailVerificationResult(bool Success, string Message);
