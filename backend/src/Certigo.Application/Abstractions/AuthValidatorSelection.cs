namespace Certigo.Application.Abstractions;

/// Decides whether the permissive developer token validator may be used, with a
/// hard environment guard. The developer validator accepts ANY bearer token as a
/// user id, so it must only run in the <c>Development</c> environment — even if
/// <c>AUTH_MODE=dev</c> accidentally leaks into a staging/prod configuration.
/// This pure decision lives in the Application layer so it is unit-testable
/// without the Functions host.
public static class AuthValidatorSelection
{
    /// Returns <see langword="true"/> when the developer validator should be wired,
    /// <see langword="false"/> for the real Entra validator. Throws when dev auth is
    /// requested outside the Development environment without an explicit override.
    public static bool ShouldUseDevValidator(string? authMode, bool isDevelopment, string? allowDevOverride)
    {
        var devRequested = string.Equals(authMode, "dev", StringComparison.OrdinalIgnoreCase);
        if (!devRequested)
        {
            return false;
        }

        var explicitlyAllowed = string.Equals(allowDevOverride, "true", StringComparison.OrdinalIgnoreCase);
        if (!isDevelopment && !explicitlyAllowed)
        {
            throw new InvalidOperationException(
                "DevTokenValidator cannot be used outside Development environment. The developer " +
                "token validator treats any bearer token as a user id and must never be deployed " +
                "to staging or production. Use Entra (unset AUTH_MODE) or set AUTH_ALLOW_DEV=true " +
                "only on a deliberately non-production smoke-test host.");
        }

        return true;
    }
}
