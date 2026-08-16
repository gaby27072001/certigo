namespace Certigo.Api;

internal static class ConfigurationKeys
{
    public const string KeyVaultUri = "KeyVault:Uri";
    public const string KeyVaultHealthSecretName = "KeyVault:HealthSecretName";
    public const string AuthJwtSigningKeySecretUri = "AUTH_JWT_SIGNING_KEY_SECRET_URI";
    public const string AuthJwtPreviousSigningKeySecretUri = "AUTH_JWT_PREVIOUS_SIGNING_KEY_SECRET_URI";
}
