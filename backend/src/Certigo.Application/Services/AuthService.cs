using System.Security.Cryptography;
using System.Text;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

/// Pure, host-independent rules for email/password input. Shared by the API
/// layer (to answer 400 on malformed input) and the service (to normalise),
/// so the two can never drift apart.
public static class AuthRules
{
    public const int MinPasswordLength = 8;
    public const int MaxPasswordLength = 256;

    public static string NormalizeEmail(string? email) => (email ?? string.Empty).Trim().ToLowerInvariant();

    /// Provider-canonical form of an email, used only for duplicate detection —
    /// NOT as the stored identity. On top of trim+lowercase, Gmail addresses are
    /// reduced to the real mailbox they hit: dots in the local part are removed,
    /// anything from a '+' onward is dropped, and googlemail.com collapses to
    /// gmail.com. So "Gabriel.Chambaud+news@googlemail.com" and
    /// "gabrielchambaud@gmail.com" share one canonical form. Non-Gmail domains are
    /// only trimmed/lower-cased (sub-addressing rules vary and stripping them
    /// would wrongly merge distinct accounts). Falls back to the plain normalised
    /// value if the local part would become empty.
    public static string CanonicalizeEmail(string? email)
    {
        var normalized = NormalizeEmail(email);
        var at = normalized.IndexOf('@');
        if (at <= 0 || at >= normalized.Length - 1)
        {
            return normalized;
        }

        var local = normalized[..at];
        var domain = normalized[(at + 1)..];

        if (domain is "gmail.com" or "googlemail.com")
        {
            var plus = local.IndexOf('+');
            if (plus >= 0)
            {
                local = local[..plus];
            }

            local = local.Replace(".", string.Empty);
            domain = "gmail.com";
        }

        return local.Length == 0 ? normalized : $"{local}@{domain}";
    }

    public static bool IsValidEmail(string? email)
    {
        var value = (email ?? string.Empty).Trim();
        if (value.Length is < 3 or > 254)
        {
            return false;
        }

        var at = value.IndexOf('@');
        // Exactly one '@', with a non-empty local part and a dotted domain.
        return at > 0
            && at == value.LastIndexOf('@')
            && at < value.Length - 1
            && value.IndexOf('.', at) > at;
    }

    public static bool IsValidPassword(string? password) =>
        !string.IsNullOrWhiteSpace(password)
        && password.Length is >= MinPasswordLength and <= MaxPasswordLength;
}

public interface IAuthService
{
    Task<AuthResultDto> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default);
    Task<AuthResultDto> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default);
    Task<AuthResultDto> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken = default);
}

/// Email/password authentication: registration (with eager profile provisioning),
/// login, and refresh. Issues locally-signed JWTs that the API validates next to
/// Entra tokens, so email users are first-class once authenticated.
public sealed class AuthService(
    IUserCredentialRepository credentials,
    IPasswordHasher passwordHasher,
    ITokenIssuer tokenIssuer,
    IUserRepository users,
    IClock clock,
    IEmailSender emailSender,
    AuthEmailOptions emailOptions) : IAuthService, IEmailVerificationService
{
    /// Failed logins allowed before an account is temporarily locked.
    private const int MaxFailedAttempts = 5;

    /// How long an account stays locked after hitting <see cref="MaxFailedAttempts"/>.
    private static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);

    /// Random bytes behind a verification token before Base64Url encoding.
    private const int VerificationTokenBytes = 32;

    private static readonly TimeSpan ProvisioningLease = TimeSpan.FromMinutes(2);

    public async Task<AuthResultDto> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
    {
        var email = AuthRules.NormalizeEmail(request.Email);
        if (!AuthRules.IsValidEmail(email))
        {
            throw new AuthFailedException("Adresse e-mail invalide.");
        }

        if (!AuthRules.IsValidPassword(request.Password))
        {
            throw new AuthFailedException($"Le mot de passe doit contenir au moins {AuthRules.MinPasswordLength} caractères.");
        }

        var canonicalEmail = AuthRules.CanonicalizeEmail(email);
        var legacy = await credentials.FindByCanonicalEmailAsync(canonicalEmail, cancellationToken);
        if (legacy is not null && !legacy.IsProvisioning)
        {
            throw new DuplicateRecordException("Cette adresse e-mail est déjà utilisée.");
        }

        var userId = legacy?.UserId ?? Guid.NewGuid().ToString("n");
        var displayName = ResolveDisplayName(request.DisplayName, email);
        var passwordHash = passwordHasher.Hash(request.Password);
        var (rawToken, tokenHash) = NewVerificationToken();

        var credential = new UserCredentialRecord(
            Id: UserCredentialRecord.CanonicalIdFor(canonicalEmail),
            Email: email,
            UserId: userId,
            DisplayName: displayName,
            PasswordHash: passwordHash,
            CreatedAt: clock.UtcNow,
            CanonicalEmail: canonicalEmail,
            EmailVerified: false,
            VerificationTokenHash: tokenHash,
            VerificationTokenExpiresAt: clock.UtcNow + emailOptions.TokenLifetime,
            ProvisioningState: CredentialProvisioningState.Pending,
            ProvisioningLeaseExpiresAt: clock.UtcNow + ProvisioningLease);

        UserCredentialRecord reservation;
        if (legacy is not null)
        {
            if (!legacy.IsProvisioning
                || legacy.ProvisioningLeaseExpiresAt is { } lease && lease > clock.UtcNow
                || !passwordHasher.Verify(request.Password, legacy.PasswordHash))
            {
                throw new DuplicateRecordException("Cette adresse e-mail est déjà utilisée.");
            }

            reservation = legacy with
            {
                Email = email,
                DisplayName = displayName,
                VerificationTokenHash = tokenHash,
                VerificationTokenExpiresAt = clock.UtcNow + emailOptions.TokenLifetime,
                ProvisioningLeaseExpiresAt = clock.UtcNow + ProvisioningLease,
            };
            await credentials.UpdateAsync(reservation, cancellationToken);
            reservation = await credentials.FindByCanonicalEmailAsync(canonicalEmail, cancellationToken)
                ?? throw new ConcurrencyConflictException("La réservation e-mail a disparu pendant sa récupération.");
        }
        else
        {
            try
            {
                reservation = await credentials.CreateAsync(credential, cancellationToken);
            }
            catch (DuplicateRecordException)
            {
                var winner = await credentials.FindByCanonicalEmailAsync(canonicalEmail, cancellationToken);
                if (winner is null
                    || !winner.IsProvisioning
                    || winner.ProvisioningLeaseExpiresAt is { } lease && lease > clock.UtcNow
                    || !passwordHasher.Verify(request.Password, winner.PasswordHash))
                {
                    throw new DuplicateRecordException("Cette adresse e-mail est déjà utilisée.");
                }

                reservation = winner;
            }
        }

        UserProfileDto profile;
        try
        {
            profile = await users.GetAsync(reservation.UserId, cancellationToken)
                ?? await users.UpsertAsync(
                    ProfileDefaults.New(reservation.UserId, reservation.DisplayName),
                    cancellationToken);
        }
        catch (DefinitivePersistenceException)
        {
            await credentials.DeletePendingAsync(reservation, cancellationToken);
            throw;
        }
        catch
        {
            UserProfileDto? committedProfile;
            try
            {
                committedProfile = await users.GetAsync(reservation.UserId, cancellationToken);
            }
            catch
            {
                // The profile write may have committed even though its response was
                // lost. Keep the leased reservation so a later registration can
                // recover it rather than creating a second identity.
                throw;
            }

            if (committedProfile is null)
            {
                // A null read does not prove absence without the failed write's
                // session token. Retain the leased reservation for safe recovery.
                throw;
            }

            profile = committedProfile;
        }

        if (reservation.IsProvisioning)
        {
            try
            {
                await credentials.UpdateAsync(
                    reservation with
                    {
                        ProvisioningState = CredentialProvisioningState.Active,
                        ProvisioningLeaseExpiresAt = null,
                    },
                    cancellationToken);
            }
            catch (ConcurrencyConflictException)
            {
                var current = await credentials.FindByCanonicalEmailAsync(canonicalEmail, cancellationToken);
                if (current?.IsProvisioning != false)
                {
                    throw;
                }
            }
        }

        await TrySendVerificationEmailAsync(email, displayName, rawToken, cancellationToken);

        return BuildResult(profile, email, emailVerified: false);
    }

    public async Task<AuthResultDto> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        var email = AuthRules.NormalizeEmail(request.Email);
        // Exact (identity) lookup first — this is the unchanged path every existing
        // account uses, so no established login is affected. Only on a miss do we
        // fall back to the canonical form, which lets a learner who typed a
        // different dot/"+tag" variant of *their own* address still sign in.
        var credential = await credentials.FindByEmailAsync(email, cancellationToken)
            ?? await credentials.FindByCanonicalEmailAsync(AuthRules.CanonicalizeEmail(email), cancellationToken);

        // Unknown email: same generic failure (no enumeration). There is no
        // account document to throttle against, so nothing is recorded.
        if (credential is null)
        {
            throw new AuthFailedException("E-mail ou mot de passe incorrect.");
        }

        // Locked out by prior failures: refuse before even checking the password
        // so a brute-force run can't keep probing.
        if (credential.LockoutUntil is { } until && until > clock.UtcNow)
        {
            throw new RateLimitedException(
                "Trop de tentatives de connexion. Réessayez dans quelques minutes.");
        }

        if (!passwordHasher.Verify(request.Password ?? string.Empty, credential.PasswordHash))
        {
            await RegisterFailedAttemptAsync(credential, cancellationToken);
            throw new AuthFailedException("E-mail ou mot de passe incorrect.");
        }

        // Successful login clears any accumulated failure state.
        if (credential.FailedAttempts != 0 || credential.LockoutUntil is not null)
        {
            await credentials.UpdateAsync(
                credential with { FailedAttempts = 0, LockoutUntil = null }, cancellationToken);
        }

        var profile = await users.GetAsync(credential.UserId, cancellationToken)
            ?? await users.UpsertAsync(ProfileDefaults.New(credential.UserId, credential.DisplayName), cancellationToken);
        return BuildResult(profile, email, credential.IsEmailVerified);
    }

    private async Task RegisterFailedAttemptAsync(UserCredentialRecord credential, CancellationToken cancellationToken)
    {
        var attempts = credential.FailedAttempts + 1;
        var locked = attempts >= MaxFailedAttempts;
        var updated = credential with
        {
            // Reset the counter when locking so the account gets a fresh window of
            // attempts once the lockout expires.
            FailedAttempts = locked ? 0 : attempts,
            LockoutUntil = locked ? clock.UtcNow + LockoutDuration : null,
        };
        await credentials.UpdateAsync(updated, cancellationToken);
    }

    public async Task<AuthResultDto> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken = default)
    {
        var principal = tokenIssuer.ValidateRefreshToken(request.RefreshToken ?? string.Empty)
            ?? throw new AuthFailedException("Session expirée, veuillez vous reconnecter.");

        var profile = await users.GetAsync(principal.UserId, cancellationToken)
            ?? await users.UpsertAsync(ProfileDefaults.New(principal.UserId, principal.DisplayName), cancellationToken);

        // Reflect the current verification state so a "confirm your email" banner
        // clears itself once the learner confirms, even across a silent refresh.
        var emailVerified = true;
        if (!string.IsNullOrWhiteSpace(principal.Email))
        {
            var credential = await credentials.FindByEmailAsync(principal.Email, cancellationToken);
            emailVerified = credential?.IsEmailVerified != false;
        }

        return BuildResult(profile, principal.Email, emailVerified);
    }

    private AuthResultDto BuildResult(UserProfileDto profile, string email, bool emailVerified = true)
    {
        var tokens = tokenIssuer.Issue(profile.Id, profile.DisplayName, email);
        return new AuthResultDto(tokens.AccessToken, tokens.RefreshToken, tokens.AccessTokenExpiresAt, profile, emailVerified);
    }

    private static string ResolveDisplayName(string? requested, string email)
    {
        if (!string.IsNullOrWhiteSpace(requested))
        {
            return requested.Trim();
        }

        var local = email.Split('@')[0];
        return string.IsNullOrWhiteSpace(local) ? "Learner" : local;
    }

    // --- Email verification -------------------------------------------------

    public async Task<EmailVerificationResult> VerifyAsync(string code, CancellationToken cancellationToken = default)
    {
        if (!TryDecodeVerificationCode(code, out var email, out var rawToken))
        {
            return new EmailVerificationResult(false, "Lien de vérification invalide.");
        }

        var credential = await credentials.FindByEmailAsync(email, cancellationToken);
        if (credential is null)
        {
            return new EmailVerificationResult(false, "Lien de vérification invalide.");
        }

        // Already confirmed (e.g. the link was clicked twice): treat as success so
        // the learner sees a friendly page, not an error.
        if (credential.IsEmailVerified && credential.VerificationTokenHash is null)
        {
            return new EmailVerificationResult(true, "Votre adresse e-mail est déjà confirmée.");
        }

        if (credential.VerificationTokenHash is null
            || credential.VerificationTokenExpiresAt is not { } expiresAt
            || expiresAt <= clock.UtcNow
            || !FixedTimeTokenEquals(rawToken, credential.VerificationTokenHash))
        {
            return new EmailVerificationResult(false, "Lien de vérification expiré ou invalide. Demandez un nouvel e-mail.");
        }

        await credentials.UpdateAsync(
            credential with
            {
                EmailVerified = true,
                VerificationTokenHash = null,
                VerificationTokenExpiresAt = null,
            },
            cancellationToken);

        return new EmailVerificationResult(true, "Adresse e-mail confirmée. Vous pouvez revenir dans l'application.");
    }

    public async Task ResendAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalized = AuthRules.NormalizeEmail(email);
        var credential = await credentials.FindByEmailAsync(normalized, cancellationToken);

        // No account, or already verified: do nothing, but never reveal which — the
        // endpoint always answers the same generic message (no enumeration).
        if (credential is null || credential.IsEmailVerified)
        {
            return;
        }

        var (rawToken, tokenHash) = NewVerificationToken();
        await credentials.UpdateAsync(
            credential with
            {
                VerificationTokenHash = tokenHash,
                VerificationTokenExpiresAt = clock.UtcNow + emailOptions.TokenLifetime,
            },
            cancellationToken);

        await TrySendVerificationEmailAsync(normalized, credential.DisplayName, rawToken, cancellationToken);
    }

    private async Task TrySendVerificationEmailAsync(string email, string displayName, string rawToken, CancellationToken cancellationToken)
    {
        try
        {
            var link = BuildVerificationLink(email, rawToken);
            var message = VerificationEmail.Build(email, displayName, link);
            await emailSender.SendAsync(message, cancellationToken);
        }
        catch
        {
            // Non-blocking by design: a mail-provider hiccup must not fail
            // registration or resend. The learner can retry via resend, and the
            // account already works (verification is a soft gate).
        }
    }

    private string BuildVerificationLink(string email, string rawToken)
    {
        var code = EncodeVerificationCode(email, rawToken);
        var separator = emailOptions.VerifyBaseUrl.Contains('?') ? '&' : '?';
        return $"{emailOptions.VerifyBaseUrl}{separator}code={Uri.EscapeDataString(code)}";
    }

    private static (string RawToken, string Hash) NewVerificationToken()
    {
        var raw = Base64UrlEncode(RandomNumberGenerator.GetBytes(VerificationTokenBytes));
        return (raw, HashToken(raw));
    }

    private static string HashToken(string rawToken)
        => Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(rawToken)));

    private static bool FixedTimeTokenEquals(string rawToken, string expectedHash)
    {
        var candidate = SHA256.HashData(Encoding.UTF8.GetBytes(rawToken));
        byte[] expected;
        try
        {
            expected = Convert.FromBase64String(expectedHash);
        }
        catch (FormatException)
        {
            return false;
        }

        return CryptographicOperations.FixedTimeEquals(candidate, expected);
    }

    /// The verification link carries an opaque code = Base64Url("{email}|{token}")
    /// so the GET endpoint resolves the exact credential (by email) and checks the
    /// token in one point read — no cross-partition lookup, no separate token store.
    private static string EncodeVerificationCode(string email, string rawToken)
        => Base64UrlEncode(Encoding.UTF8.GetBytes($"{email}|{rawToken}"));

    private static bool TryDecodeVerificationCode(string? code, out string email, out string rawToken)
    {
        email = string.Empty;
        rawToken = string.Empty;
        if (string.IsNullOrWhiteSpace(code))
        {
            return false;
        }

        try
        {
            var decoded = Encoding.UTF8.GetString(Base64UrlDecode(code));
            var separator = decoded.IndexOf('|');
            if (separator <= 0 || separator >= decoded.Length - 1)
            {
                return false;
            }

            email = decoded[..separator];
            rawToken = decoded[(separator + 1)..];
            return true;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static string Base64UrlEncode(byte[] bytes)
        => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] Base64UrlDecode(string value)
    {
        var padded = value.Replace('-', '+').Replace('_', '/');
        padded = (padded.Length % 4) switch
        {
            2 => padded + "==",
            3 => padded + "=",
            _ => padded,
        };
        return Convert.FromBase64String(padded);
    }
}

/// Pure builder for the confirmation email (French). Host- and provider-agnostic
/// so the copy is unit-testable and identical across every <see cref="IEmailSender"/>.
internal static class VerificationEmail
{
    public static EmailMessage Build(string email, string displayName, string link)
    {
        var greetingName = string.IsNullOrWhiteSpace(displayName) ? string.Empty : $" {displayName.Trim()}";
        const string subject = "Confirmez votre adresse e-mail — Certigo";

        var text =
            $"Bonjour{greetingName},\n\n" +
            "Confirmez votre adresse e-mail pour sécuriser votre compte Certigo :\n" +
            link + "\n\n" +
            "Ce lien expire dans 24 heures. Si vous n'êtes pas à l'origine de cette inscription, ignorez cet e-mail.\n\n" +
            "— L'équipe Certigo";

        var safeName = System.Net.WebUtility.HtmlEncode(greetingName);
        var safeLink = System.Net.WebUtility.HtmlEncode(link);
        var html =
            "<div style=\"font-family:Segoe UI,Arial,sans-serif;font-size:15px;color:#1b1b1f\">" +
            $"<p>Bonjour{safeName},</p>" +
            "<p>Confirmez votre adresse e-mail pour sécuriser votre compte Certigo :</p>" +
            $"<p><a href=\"{safeLink}\" style=\"background:#4f46e5;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none;display:inline-block\">Confirmer mon e-mail</a></p>" +
            $"<p style=\"color:#6b7280;font-size:13px\">Ou copiez ce lien&nbsp;: {safeLink}</p>" +
            "<p style=\"color:#6b7280;font-size:13px\">Ce lien expire dans 24&nbsp;heures. Si vous n'êtes pas à l'origine de cette inscription, ignorez cet e-mail.</p>" +
            "<p>— L'équipe Certigo</p></div>";

        return new EmailMessage(email, string.IsNullOrWhiteSpace(displayName) ? null : displayName, subject, html, text);
    }
}
