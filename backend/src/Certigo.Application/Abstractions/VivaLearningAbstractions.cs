using Certigo.Application.Dtos;

namespace Certigo.Application.Abstractions;

public enum VivaLearningFeatureMode
{
    Off,
}

public sealed record VivaLearningFeatureOptions(
    VivaLearningFeatureMode Mode,
    Uri PublicWebOrigin)
{
    private static readonly Uri DisabledOrigin = new("https://links-disabled.invalid/");

    public static VivaLearningFeatureOptions Parse(string? mode, string? publicWebOrigin)
    {
        if (!string.IsNullOrWhiteSpace(mode)
            && !string.Equals(mode.Trim(), "off", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "VIVA_LEARNING_V1 only supports 'off' in this contract increment.");
        }

        // The global public origin must never make a disabled connector routable.
        _ = publicWebOrigin;
        return new VivaLearningFeatureOptions(VivaLearningFeatureMode.Off, DisabledOrigin);
    }

    public static Uri ParseFixtureOrigin(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return DisabledOrigin;
        }
        if (!Uri.TryCreate(value, UriKind.Absolute, out var origin)
            || !string.Equals(origin.Scheme, Uri.UriSchemeHttps, StringComparison.Ordinal)
            || !origin.IsDefaultPort
            || origin.AbsolutePath != "/"
            || !string.IsNullOrEmpty(origin.Query)
            || !string.IsNullOrEmpty(origin.Fragment)
            || !origin.Host.EndsWith(".invalid", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "PUBLIC_WEB_ORIGIN must be an HTTPS .invalid root origin for fixture-only Viva Learning contracts.");
        }

        return origin;
    }
}

public enum VivaLearningAuthMode
{
    DelegatedAdministrator,
    DelegatedUser,
    Application,
}

public sealed record VivaLearningPermissionContract(
    string Operation,
    VivaLearningAuthMode AuthMode,
    string Permission)
{
    public static IReadOnlyList<VivaLearningPermissionContract> All { get; } =
    [
        new(
            "Register provider",
            VivaLearningAuthMode.DelegatedAdministrator,
            "LearningProvider.ReadWrite"),
        new(
            "Publish content",
            VivaLearningAuthMode.Application,
            "LearningContent.ReadWrite.All"),
        new(
            "Read my assignments",
            VivaLearningAuthMode.DelegatedUser,
            "LearningAssignedCourse.Read.All"),
        new(
            "Sync assignment progress",
            VivaLearningAuthMode.Application,
            "LearningAssignedCourse.ReadWrite.All"),
    ];
}

public sealed record VivaLearningTenantConsent(
    string OrganizationId,
    string EnterpriseTenantId,
    IReadOnlySet<string> GrantedPermissions,
    DateTimeOffset GrantedAt,
    DateTimeOffset? RevokedAt);

public interface IVivaLearningTenantConsentStore
{
    Task<VivaLearningTenantConsent?> GetAsync(
        string organizationId,
        CancellationToken cancellationToken = default);

    Task SaveAsync(
        VivaLearningTenantConsent consent,
        CancellationToken cancellationToken = default);
}

public sealed record EncryptedTokenEnvelope(
    string KeyId,
    string Algorithm,
    byte[] Ciphertext,
    byte[] Nonce,
    byte[] AuthenticationTag,
    DateTimeOffset ExpiresAt);

public sealed record VivaLearningTokenCacheKey(
    string OrganizationId,
    string EnterpriseTenantId,
    VivaLearningAuthMode AuthMode,
    string? EnterpriseSubjectId)
{
    public void EnsureValid()
    {
        if (string.IsNullOrWhiteSpace(OrganizationId)
            || string.IsNullOrWhiteSpace(EnterpriseTenantId))
        {
            throw new ArgumentException(
                "Organization and enterprise tenant identifiers are required.");
        }

        var delegated = AuthMode is VivaLearningAuthMode.DelegatedAdministrator
            or VivaLearningAuthMode.DelegatedUser;
        if (delegated != !string.IsNullOrWhiteSpace(EnterpriseSubjectId))
        {
            throw new ArgumentException(
                "Delegated cache keys require an opaque enterprise subject; application keys must not include one.");
        }
    }
}

public interface IVivaLearningEncryptedTokenCache
{
    Task<EncryptedTokenEnvelope?> GetAsync(
        VivaLearningTokenCacheKey key,
        CancellationToken cancellationToken = default);

    Task SetAsync(
        VivaLearningTokenCacheKey key,
        EncryptedTokenEnvelope envelope,
        CancellationToken cancellationToken = default);

    Task RemoveAsync(
        VivaLearningTokenCacheKey key,
        CancellationToken cancellationToken = default);
}

public interface IVivaLearningFixtureCatalog
{
    VivaLearningProviderDto Provider { get; }
    IReadOnlyList<VivaLearningContentFixtureDto> LearningContent { get; }
}

public interface IVivaLearningService
{
    Task<VivaLearningProviderDto> GetProviderAsync(
        string organizationId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<VivaLearningContentDto>> GetLearningContentAsync(
        string organizationId,
        CancellationToken cancellationToken = default);
}

public sealed class VivaLearningFeatureDisabledException()
    : Exception("The Viva Learning V1 surface is disabled.");
