using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;

namespace Certigo.Domain.Identity;

public sealed record PersonIdentityMetadata(
    int SchemaVersion,
    string PersonId,
    string LegacyUserId,
    string MigrationState,
    string? AnchorLinkedIdentityId,
    DateTimeOffset MigratedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string ShadowMigrationState = "shadow";
    public const string ResolvedMigrationState = "resolved";

    public static PersonIdentityMetadata Shadow(string personId, DateTimeOffset migratedAt)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(personId);
        return new PersonIdentityMetadata(
            CurrentSchemaVersion,
            personId,
            personId,
            ShadowMigrationState,
            null,
            migratedAt);
    }

    public void EnsureConsistentWith(string profileId)
    {
        if (SchemaVersion != CurrentSchemaVersion
            || !string.Equals(PersonId, profileId, StringComparison.Ordinal)
            || !string.Equals(LegacyUserId, profileId, StringComparison.Ordinal)
            || MigrationState is not (ShadowMigrationState or ResolvedMigrationState))
        {
            throw new PersonIdentityIntegrityException();
        }
    }
}

public sealed record IdentityLocator(
    string Provider,
    string Tenant,
    string Subject,
    string Type)
{
    public const string LocalProvider = "certigo-local";
    public const string EntraProvider = "entra-external-id";
    public const string LocalTenant = "certigo";
    public const string LocalPasswordType = "localPassword";
    public const string EntraExternalIdType = "entraExternalId";

    public IdentityLocator EnsureCanonical()
    {
        if (!IsCanonicalText(Provider)
            || !IsCanonicalText(Tenant)
            || !IsCanonicalText(Subject)
            || !IsCanonicalText(Type))
        {
            throw new InvalidIdentityLocatorException();
        }

        var isLocal = Provider == LocalProvider
            && Tenant == LocalTenant
            && Type == LocalPasswordType
            && IsLowerHex(Subject, 32);
        var isEntra = Provider == EntraProvider
            && Type == EntraExternalIdType
            && IsCanonicalGuid(Tenant)
            && IsCanonicalGuid(Subject);
        if (!isLocal && !isEntra)
        {
            throw new InvalidIdentityLocatorException();
        }

        return this;
    }

    public string StableId()
    {
        var canonical = EnsureCanonical();
        return $"linked-identity::v1::{PersonIdentityDocumentIds.Hash(
            "certigo-linked-identity:v1",
            canonical.Provider,
            canonical.Tenant,
            canonical.Subject,
            canonical.Type)}";
    }

    private static bool IsCanonicalText(string value) =>
        !string.IsNullOrWhiteSpace(value)
        && value == value.Trim()
        && !value.Any(char.IsControl);

    private static bool IsLowerHex(string value, int minimumLength) =>
        value.Length >= minimumLength
        && value.All(character =>
            character is >= '0' and <= '9'
            || character is >= 'a' and <= 'f');

    private static bool IsCanonicalGuid(string value) =>
        Guid.TryParseExact(value, "D", out var parsed)
        && string.Equals(
            parsed.ToString("D", CultureInfo.InvariantCulture),
            value,
            StringComparison.Ordinal);
}

public sealed record LinkedIdentityVerification(
    string State,
    string Method,
    DateTimeOffset VerifiedAt,
    DateTimeOffset AuthenticatedAt,
    string? Issuer,
    string? Audience)
{
    public const string VerifiedState = "verified";
    public const string LegacyCredentialBackfillMethod = "legacyCredentialBackfill";
    public const string LocalPasswordReauthenticationMethod = "localPasswordReauthentication";
    public const string OidcReauthenticationMethod = "oidcReauthentication";
}

public sealed record LinkedIdentityRevocation(
    string State,
    int Generation,
    string ProviderAction,
    DateTimeOffset? RevokedAt,
    string? Reason,
    string? OperationId)
{
    public const string ActiveState = "active";
    public const string PendingState = "pending";
    public const string RevokedState = "revoked";
    public const string NotApplicableProviderAction = "notApplicable";
    public const string NotRequestedProviderAction = "notRequested";
    public const string PendingProviderAction = "pending";
    public const string CompletedProviderAction = "completed";
    public const string FailedProviderAction = "failed";
    public const string AccountDeletionReason = "accountDeletion";

    public static LinkedIdentityRevocation Active() =>
        new(ActiveState, 1, NotRequestedProviderAction, null, null, null);
}

public sealed record LinkedIdentity(
    string Id,
    int SchemaVersion,
    string PersonId,
    IdentityLocator Locator,
    LinkedIdentityVerification Verification,
    LinkedIdentityRevocation Revocation,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string LinkedIdentityDocumentType = "linkedIdentity";

    public string DocumentType => LinkedIdentityDocumentType;

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static LinkedIdentity Create(
        string personId,
        IdentityLocator locator,
        LinkedIdentityVerification verification,
        DateTimeOffset createdAt)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(personId);
        var canonical = locator.EnsureCanonical();
        return new LinkedIdentity(
            canonical.StableId(),
            CurrentSchemaVersion,
            personId,
            canonical,
            verification,
            LinkedIdentityRevocation.Active(),
            createdAt,
            createdAt);
    }

    public void EnsureValid()
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(PersonId);
        var canonical = Locator.EnsureCanonical();
        if (SchemaVersion != CurrentSchemaVersion
            || !string.Equals(Id, canonical.StableId(), StringComparison.Ordinal)
            || Verification.State != LinkedIdentityVerification.VerifiedState
            || Revocation.Generation < 1)
        {
            throw new PersonIdentityIntegrityException();
        }
    }
}

public sealed record IdentityLinkIntent(
    string Id,
    int SchemaVersion,
    string PersonId,
    string SourceLinkedIdentityId,
    string TargetProvider,
    string TargetTenant,
    string TargetType,
    string NonceHash,
    string RequestHash,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt,
    DateTimeOffset? ConsumedAt = null,
    string? ResultOperationId = null)
{
    public const int CurrentSchemaVersion = 1;
    public const string IdentityLinkIntentDocumentType = "identityLinkIntent";

    public string DocumentType => IdentityLinkIntentDocumentType;

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static string IdFor(string personId, string idempotencyKey) =>
        $"identity-link-intent::v1::{PersonIdentityDocumentIds.Hash(
            "certigo-identity-link-intent:v1",
            personId,
            idempotencyKey)}";
}

public sealed record IdentityLinkOperation(
    string Id,
    int SchemaVersion,
    string PersonId,
    string IntentId,
    string? LinkedIdentityId,
    string IdempotencyKeyHash,
    string RequestHash,
    string Status,
    string? FailureCode,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string IdentityLinkOperationDocumentType = "identityLinkOperation";

    public string DocumentType => IdentityLinkOperationDocumentType;

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static string IdFor(string personId, string idempotencyKey) =>
        $"identity-link-operation::v1::{PersonIdentityDocumentIds.Hash(
            "certigo-identity-link-operation:v1",
            personId,
            idempotencyKey)}";
}

public static class PersonIdentityDocumentIds
{
    public static string Hash(params string[] values)
    {
        if (values.Any(string.IsNullOrWhiteSpace))
        {
            throw new ArgumentException("Identity hash inputs must not be blank.", nameof(values));
        }

        var material = string.Join("\0", values);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(material)))
            .ToLowerInvariant();
    }
}

public sealed class InvalidIdentityLocatorException()
    : Exception("The identity locator is not canonical.");

public sealed class PersonIdentityIntegrityException()
    : Exception("The Person/LinkedIdentity integrity contract was violated.");
