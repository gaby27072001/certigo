using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;

namespace Microlingo.Application.Services;

/// Pure, host-independent rules for email/password input. Shared by the API
/// layer (to answer 400 on malformed input) and the service (to normalise),
/// so the two can never drift apart.
public static class AuthRules
{
    public const int MinPasswordLength = 8;
    public const int MaxPasswordLength = 256;

    public static string NormalizeEmail(string? email) => (email ?? string.Empty).Trim().ToLowerInvariant();

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
        !string.IsNullOrEmpty(password)
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
    IClock clock) : IAuthService
{
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

        var userId = Guid.NewGuid().ToString("n");
        var displayName = ResolveDisplayName(request.DisplayName, email);
        var passwordHash = passwordHasher.Hash(request.Password);

        var credential = new UserCredentialRecord(
            Id: UserCredentialRecord.IdFor(email),
            Email: email,
            UserId: userId,
            DisplayName: displayName,
            PasswordHash: passwordHash,
            CreatedAt: clock.UtcNow);

        try
        {
            await credentials.CreateAsync(credential, cancellationToken);
        }
        catch (DuplicateRecordException)
        {
            // Re-shaped to a clear, user-facing French message; still a 409.
            throw new DuplicateRecordException("Cette adresse e-mail est déjà utilisée.");
        }

        // Provision the profile eagerly so the home screen has data immediately.
        var profile = await users.UpsertAsync(ProfileDefaults.New(userId, displayName), cancellationToken);
        return BuildResult(profile, email);
    }

    public async Task<AuthResultDto> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        var email = AuthRules.NormalizeEmail(request.Email);
        var credential = await credentials.FindByEmailAsync(email, cancellationToken);

        // Same generic message whether the email is unknown or the password is
        // wrong, so the endpoint never reveals which emails are registered.
        if (credential is null || !passwordHasher.Verify(request.Password ?? string.Empty, credential.PasswordHash))
        {
            throw new AuthFailedException("E-mail ou mot de passe incorrect.");
        }

        var profile = await users.GetAsync(credential.UserId, cancellationToken)
            ?? await users.UpsertAsync(ProfileDefaults.New(credential.UserId, credential.DisplayName), cancellationToken);
        return BuildResult(profile, email);
    }

    public async Task<AuthResultDto> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken = default)
    {
        var principal = tokenIssuer.ValidateRefreshToken(request.RefreshToken ?? string.Empty)
            ?? throw new AuthFailedException("Session expirée, veuillez vous reconnecter.");

        var profile = await users.GetAsync(principal.UserId, cancellationToken)
            ?? await users.UpsertAsync(ProfileDefaults.New(principal.UserId, principal.DisplayName), cancellationToken);
        return BuildResult(profile, principal.Email);
    }

    private AuthResultDto BuildResult(UserProfileDto profile, string email)
    {
        var tokens = tokenIssuer.Issue(profile.Id, profile.DisplayName, email);
        return new AuthResultDto(tokens.AccessToken, tokens.RefreshToken, tokens.AccessTokenExpiresAt, profile);
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
}
