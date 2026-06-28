namespace Certigo.Application.Abstractions;

/// Decides whether the permissive developer token validator may be used, with a
/// hard production guard. The developer validator accepts ANY bearer token as a
/// user id, so it must never run in production — even if <c>AUTH_MODE=dev</c>
/// accidentally leaks into a deployment's configuration. This pure decision lives
/// in the Application layer so it is unit-testable without the Functions host.
public static class AuthValidatorSelection
{
    /// Returns <see langword="true"/> when the developer validator should be wired,
    /// <see langword="false"/> for the real Entra validator. Throws when dev auth is
    /// requested in a production environment without an explicit, non-production
    /// override.
    public static bool ShouldUseDevValidator(string? authMode, bool isProduction, string? allowDevOverride)
    {
        var devRequested = string.Equals(authMode, "dev", StringComparison.OrdinalIgnoreCase);
        if (!devRequested)
        {
            return false;
        }

        var explicitlyAllowed = string.Equals(allowDevOverride, "true", StringComparison.OrdinalIgnoreCase);
        if (isProduction && !explicitlyAllowed)
        {
            throw new InvalidOperationException(
                "AUTH_MODE=dev is forbidden in a Production environment. The developer token " +
                "validator treats any bearer token as a user id and must never be deployed to " +
                "production. Use Entra (unset AUTH_MODE) or set AUTH_ALLOW_DEV=true only on a " +
                "deliberately non-production smoke-test host.");
        }

        return true;
    }
}
