namespace Certigo.Application.Abstractions;

/// Resolves the symmetric signing secret used for the locally-issued email/password
/// JWTs, applying a hard fail-fast guard for production. The built-in development key
/// is weak and publicly known, so a hardened (production) deployment must never sign
/// tokens with it: when the configured key is missing, blank, or still the built-in
/// placeholder, startup fails loudly instead of silently accepting forgeable tokens.
/// Outside production the placeholder is tolerated so the email/password flow works
/// out of the box locally. This pure decision lives in the Application layer so it is
/// unit-testable without the Functions host (mirrors <see cref="AuthValidatorSelection"/>).
public static class JwtSigningKeyGuard
{
    /// The built-in development signing secret. It is intentionally weak and public,
    /// so it may only ever be used outside a hardened (production) environment.
    public const string DevelopmentSigningKey = "certigo-dev-signing-key-change-me";

    /// Returns the signing secret to use, or throws in a hardened environment when no
    /// strong key was supplied. An environment is hardened when the host is Production
    /// or <c>AUTH_MODE=prod</c>. In a hardened environment the key must be present,
    /// non-blank, and different from <see cref="DevelopmentSigningKey"/>; otherwise an
    /// <see cref="InvalidOperationException"/> is thrown at startup (fail-fast). Outside
    /// production, an absent key falls back to the development placeholder.
    public static string ResolveSigningSecret(string? configuredSecret, bool isProduction, string? authMode)
    {
        var hardened = isProduction
            || string.Equals(authMode?.Trim(), "prod", StringComparison.OrdinalIgnoreCase);

        var trimmed = configuredSecret?.Trim();
        var isStrongKey = !string.IsNullOrEmpty(trimmed)
            && !string.Equals(trimmed, DevelopmentSigningKey, StringComparison.Ordinal)
            && !IsUnresolvedKeyVaultReference(trimmed);

        if (hardened && !isStrongKey)
        {
            throw new InvalidOperationException(
                "AUTH_JWT_SIGNING_KEY must be provided in production to sign email/password " +
                "tokens; the built-in development key is forbidden. Configure a strong, secret " +
                "AUTH_JWT_SIGNING_KEY (the default \"" + DevelopmentSigningKey + "\" is rejected " +
                "outside development).");
        }

        // Nominal production path returns the configured key verbatim (behaviour unchanged).
        // Development tolerates an absent key by falling back to the development placeholder.
        return string.IsNullOrWhiteSpace(configuredSecret) ? DevelopmentSigningKey : configuredSecret;
    }

    /// Returns the optional previous signing secret used only to validate tokens during
    /// a planned rotation overlap. Hardened environments reject the public development
    /// key here as strictly as they reject it for the active signer.
    public static string? ResolvePreviousSigningSecret(
        string? configuredSecret,
        string activeSigningSecret,
        bool isProduction,
        string? authMode)
    {
        if (string.IsNullOrWhiteSpace(configuredSecret))
        {
            return null;
        }

        var hardened = isProduction
            || string.Equals(authMode?.Trim(), "prod", StringComparison.OrdinalIgnoreCase);
        var trimmed = configuredSecret.Trim();
        if (IsUnresolvedKeyVaultReference(trimmed))
        {
            throw new InvalidOperationException(
                "AUTH_JWT_PREVIOUS_SIGNING_KEY contains an unresolved Key Vault reference.");
        }
        if (hardened
            && string.Equals(trimmed, DevelopmentSigningKey, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "AUTH_JWT_PREVIOUS_SIGNING_KEY cannot use the built-in development key " +
                "in a hardened environment.");
        }
        if (string.Equals(configuredSecret, activeSigningSecret, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "AUTH_JWT_PREVIOUS_SIGNING_KEY must differ from the active signing key.");
        }

        return configuredSecret;
    }

    private static bool IsUnresolvedKeyVaultReference(string value)
        => value.StartsWith("@Microsoft.KeyVault(", StringComparison.OrdinalIgnoreCase);
}
