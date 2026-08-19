namespace Certigo.Api;

internal static class ConfigurationKeys
{
    public const string KeyVaultUri = "KeyVault:Uri";
    public const string KeyVaultHealthSecretName = "KeyVault:HealthSecretName";
    public const string AuthJwtSigningKeySecretUri = "AUTH_JWT_SIGNING_KEY_SECRET_URI";
    public const string AuthJwtPreviousSigningKeySecretUri = "AUTH_JWT_PREVIOUS_SIGNING_KEY_SECRET_URI";
    public const string ContentBlobEndpoint = "CONTENT_BLOB_ENDPOINT";
    public const string ContentStorageClientId = "CONTENT_STORAGE_CLIENT_ID";
    public const string ContentDescriptorContainer = "CONTENT_DESCRIPTOR_CONTAINER";
    public const string ContentPublicContainer = "CONTENT_PUBLIC_CONTAINER";
    public const string ContentPrivateContainer = "CONTENT_PRIVATE_CONTAINER";
    public const string ContentRepositoryMode = "CONTENT_REPOSITORY_MODE";
    public const string ContentAdminRole = "CONTENT_ADMIN_ROLE";
    public const string ContentAdminAllowDev = "CONTENT_ADMIN_ALLOW_DEV";
}
