using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;

namespace Certigo.Domain.Organizations;

public enum EnterpriseDomainStatus
{
    Pending,
    Verified,
    Suspended,
}

public enum EnterpriseDomainClaimStatus
{
    Pending,
    Verified,
    Released,
}

public enum ScimTokenState
{
    Active,
    Revoked,
}

public enum EnterpriseFederationProtocol
{
    Oidc,
    Saml,
}

public enum EnterpriseAuditAction
{
    DomainChallengeCreated,
    DomainVerified,
    FederationConfigured,
    ScimTokenCreated,
    ScimTokenRotated,
    ScimUserProvisioned,
    ScimUserBound,
    ScimUserDeprovisioned,
    ScimGroupProvisioned,
}

public sealed record EnterpriseDomainVerification(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string CanonicalDomain,
    string ChallengeHash,
    string CreationRequestHash,
    EnterpriseDomainStatus Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt,
    DateTimeOffset? VerifiedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "enterpriseDomainVerification";
    public static readonly TimeSpan ChallengeLifetime = TimeSpan.FromHours(24);

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static EnterpriseDomainVerification Create(
        string organizationId,
        string domain,
        string idempotencyKey,
        string challenge,
        DateTimeOffset createdAt)
    {
        EnterpriseIdentityRules.EnsureIdentifier(organizationId, nameof(organizationId));
        EnterpriseIdentityRules.EnsureIdempotencyKey(idempotencyKey);
        EnterpriseIdentityRules.EnsureSecret(challenge);
        var canonicalDomain = EnterpriseIdentityRules.CanonicalDomain(domain);
        return new EnterpriseDomainVerification(
            EnterpriseIdentityDocumentIds.Domain(canonicalDomain),
            organizationId,
            CurrentSchemaVersion,
            Type,
            canonicalDomain,
            EnterpriseIdentityDocumentIds.Hash(
                "certigo-enterprise-domain-challenge:v1",
                challenge),
            EnterpriseIdentityDocumentIds.Hash(
                "certigo-enterprise-domain-request:v1",
                organizationId,
                canonicalDomain),
            EnterpriseDomainStatus.Pending,
            createdAt,
            createdAt.Add(ChallengeLifetime),
            null);
    }

    public EnterpriseDomainVerification Verify(string organizationId, string challenge, DateTimeOffset now)
    {
        EnsureOrganization(organizationId);
        EnterpriseIdentityRules.EnsureSecret(challenge);
        if (Status != EnterpriseDomainStatus.Pending)
        {
            throw new EnterpriseReplayException();
        }
        if (now >= ExpiresAt)
        {
            throw new EnterpriseDomainChallengeExpiredException();
        }
        if (!EnterpriseIdentityDocumentIds.FixedTimeMatches(
                ChallengeHash,
                "certigo-enterprise-domain-challenge:v1",
                challenge))
        {
            throw new EnterpriseCredentialException();
        }
        return this with { Status = EnterpriseDomainStatus.Verified, VerifiedAt = now };
    }

    public void EnsureOrganization(string organizationId)
    {
        if (!string.Equals(OrganizationId, organizationId, StringComparison.Ordinal))
        {
            throw new OrganizationNotFoundException();
        }
    }
}

public sealed record EnterpriseDomainClaim(
    string Id,
    int SchemaVersion,
    string DocumentType,
    string DomainHash,
    string OrganizationBindingHash,
    EnterpriseDomainClaimStatus Status,
    DateTimeOffset ReservedAt,
    DateTimeOffset ExpiresAt,
    DateTimeOffset? ReleasedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "enterpriseDomainClaim";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static EnterpriseDomainClaim Create(EnterpriseDomainVerification verification)
    {
        var domainHash = EnterpriseIdentityDocumentIds.Hash(
            "certigo-enterprise-domain:v1",
            verification.CanonicalDomain);
        return new EnterpriseDomainClaim(
            $"enterprise-domain-claim::v1::{domainHash}",
            CurrentSchemaVersion,
            Type,
            domainHash,
            OrganizationBinding(verification.OrganizationId),
            EnterpriseDomainClaimStatus.Pending,
            verification.CreatedAt,
            verification.ExpiresAt,
            null);
    }

    public void EnsureOwnedBy(string organizationId)
    {
        var expected = OrganizationBinding(organizationId);
        if (!EnterpriseIdentityDocumentIds.FixedTimeEqualsHex(
                OrganizationBindingHash,
                expected)
            || Status == EnterpriseDomainClaimStatus.Released)
        {
            throw new EnterpriseDomainAlreadyClaimedException();
        }
    }

    public EnterpriseDomainClaim Confirm(
        string organizationId,
        DateTimeOffset confirmedAt)
    {
        EnsureOwnedBy(organizationId);
        if (Status != EnterpriseDomainClaimStatus.Pending || confirmedAt >= ExpiresAt)
        {
            throw new EnterpriseReplayException();
        }
        return this with { Status = EnterpriseDomainClaimStatus.Verified };
    }

    public EnterpriseDomainClaim Release(
        string organizationId,
        DateTimeOffset releasedAt)
    {
        EnsureOwnedBy(organizationId);
        if (string.IsNullOrWhiteSpace(ETag))
        {
            throw new EnterpriseConcurrencyTokenException();
        }
        return this with
        {
            Status = EnterpriseDomainClaimStatus.Released,
            ReleasedAt = releasedAt,
        };
    }

    private static string OrganizationBinding(string organizationId)
    {
        EnterpriseIdentityRules.EnsureIdentifier(organizationId, nameof(organizationId));
        return EnterpriseIdentityDocumentIds.Hash(
            "certigo-enterprise-domain-organization-binding:v1",
            organizationId);
    }
}

public sealed record EnterpriseFederationConnection(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    EnterpriseFederationProtocol Protocol,
    string Issuer,
    string Audience,
    Uri MetadataEndpoint,
    bool Enabled,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "enterpriseFederationConnection";

    public static EnterpriseFederationConnection Create(
        string organizationId,
        EnterpriseFederationProtocol protocol,
        string issuer,
        string audience,
        string metadataEndpoint,
        DateTimeOffset createdAt)
    {
        EnterpriseIdentityRules.EnsureIdentifier(organizationId, nameof(organizationId));
        EnterpriseIdentityRules.EnsureIdentifier(issuer, nameof(issuer));
        EnterpriseIdentityRules.EnsureIdentifier(audience, nameof(audience));
        if (!Enum.IsDefined(protocol)
            || !Uri.TryCreate(metadataEndpoint, UriKind.Absolute, out var endpoint)
            || endpoint.Scheme != Uri.UriSchemeHttps
            || !string.IsNullOrEmpty(endpoint.UserInfo)
            || !string.IsNullOrEmpty(endpoint.Fragment))
        {
            throw new EnterpriseIdentityValidationException("Federation metadata is invalid.");
        }
        return new EnterpriseFederationConnection(
            EnterpriseIdentityDocumentIds.Federation(organizationId, protocol, issuer),
            organizationId,
            CurrentSchemaVersion,
            Type,
            protocol,
            issuer,
            audience,
            endpoint,
            false,
            createdAt,
            createdAt);
    }
}

public sealed record ScimTokenCredential(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    int Generation,
    string CurrentTokenHash,
    string? PreviousTokenHash,
    DateTimeOffset? PreviousValidUntil,
    ScimTokenState State,
    DateTimeOffset CreatedAt,
    DateTimeOffset NotBefore,
    DateTimeOffset ExpiresAt,
    DateTimeOffset RotatedAt,
    DateTimeOffset? RevokedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "scimTokenCredential";
    public static readonly TimeSpan DefaultLifetime = TimeSpan.FromDays(90);

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static ScimTokenCredential Create(
        string organizationId,
        string token,
        DateTimeOffset createdAt)
    {
        EnterpriseIdentityRules.EnsureIdentifier(organizationId, nameof(organizationId));
        EnterpriseIdentityRules.EnsureSecret(token);
        return new ScimTokenCredential(
            EnterpriseIdentityDocumentIds.ScimToken(organizationId),
            organizationId,
            CurrentSchemaVersion,
            Type,
            1,
            HashToken(token),
            null,
            null,
            ScimTokenState.Active,
            createdAt,
            createdAt,
            createdAt.Add(DefaultLifetime),
            createdAt,
            null);
    }

    public ScimTokenCredential Rotate(
        string organizationId,
        string token,
        DateTimeOffset rotatedAt,
        TimeSpan overlap)
    {
        EnsureOrganization(organizationId);
        EnterpriseIdentityRules.EnsureSecret(token);
        EnsureMutable();
        if (rotatedAt >= ExpiresAt)
        {
            throw new EnterpriseCredentialException();
        }
        if (overlap < TimeSpan.Zero || overlap > TimeSpan.FromHours(24))
        {
            throw new EnterpriseIdentityValidationException(
                "SCIM token overlap must be between zero and 24 hours.");
        }
        return this with
        {
            Generation = checked(Generation + 1),
            CurrentTokenHash = HashToken(token),
            PreviousTokenHash = CurrentTokenHash,
            PreviousValidUntil = ExpiresAt < rotatedAt.Add(overlap)
                ? ExpiresAt
                : rotatedAt.Add(overlap),
            State = ScimTokenState.Active,
            NotBefore = rotatedAt,
            ExpiresAt = rotatedAt.Add(DefaultLifetime),
            RotatedAt = rotatedAt,
            RevokedAt = null,
        };
    }

    public ScimTokenCredential Revoke(string organizationId, DateTimeOffset revokedAt)
    {
        EnsureOrganization(organizationId);
        EnsureMutable();
        return this with
        {
            State = ScimTokenState.Revoked,
            PreviousTokenHash = null,
            PreviousValidUntil = null,
            RevokedAt = revokedAt,
        };
    }

    public bool Authenticates(string organizationId, string token, DateTimeOffset now)
    {
        EnsureOrganization(organizationId);
        EnterpriseIdentityRules.EnsureSecret(token);
        if (State != ScimTokenState.Active || now < NotBefore || now >= ExpiresAt)
        {
            return false;
        }
        var current = EnterpriseIdentityDocumentIds.FixedTimeMatches(
            CurrentTokenHash,
            "certigo-scim-token:v1",
            token);
        var previous = PreviousTokenHash is not null
            && PreviousValidUntil is not null
            && now < PreviousValidUntil
            && EnterpriseIdentityDocumentIds.FixedTimeMatches(
                PreviousTokenHash,
                "certigo-scim-token:v1",
                token);
        return current || previous;
    }

    private static string HashToken(string token) =>
        EnterpriseIdentityDocumentIds.Hash("certigo-scim-token:v1", token);

    private void EnsureMutable()
    {
        if (State != ScimTokenState.Active || string.IsNullOrWhiteSpace(ETag))
        {
            throw new EnterpriseConcurrencyTokenException();
        }
    }

    private void EnsureOrganization(string organizationId)
    {
        if (!string.Equals(OrganizationId, organizationId, StringComparison.Ordinal))
        {
            throw new OrganizationNotFoundException();
        }
    }
}

public sealed record ScimProvisionedUser(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string ExternalIdHash,
    string UserNameHash,
    string RequestHash,
    bool Active,
    OrganizationRole Role,
    string? PersonId,
    string? LinkedIdentityId,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? DeprovisionedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "scimProvisionedUser";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static ScimProvisionedUser Create(
        string organizationId,
        string externalId,
        string userName,
        OrganizationRole role,
        string idempotencyKey,
        DateTimeOffset createdAt)
    {
        EnterpriseIdentityRules.EnsureIdentifier(organizationId, nameof(organizationId));
        EnterpriseIdentityRules.EnsureIdentifier(externalId, nameof(externalId));
        EnterpriseIdentityRules.EnsureIdentifier(userName, nameof(userName));
        EnterpriseIdentityRules.EnsureIdempotencyKey(idempotencyKey);
        if (role is not (OrganizationRole.Manager or OrganizationRole.Learner))
        {
            throw new OrganizationAccessDeniedException();
        }
        var externalIdHash = EnterpriseIdentityDocumentIds.Hash(
            "certigo-scim-external-id:v1",
            organizationId,
            externalId);
        return new ScimProvisionedUser(
            EnterpriseIdentityDocumentIds.ScimUser(organizationId, externalIdHash),
            organizationId,
            CurrentSchemaVersion,
            Type,
            externalIdHash,
            EnterpriseIdentityDocumentIds.Hash(
                "certigo-scim-user-name:v1",
                organizationId,
                userName.Trim().ToLowerInvariant()),
            EnterpriseIdentityDocumentIds.Hash(
                "certigo-scim-user-request:v1",
                organizationId,
                externalIdHash,
                role.ToString(),
                idempotencyKey),
            true,
            role,
            null,
            null,
            createdAt,
            createdAt,
            null);
    }

    public ScimProvisionedUser Bind(
        string organizationId,
        string personId,
        string linkedIdentityId,
        DateTimeOffset updatedAt)
    {
        EnsureOrganization(organizationId);
        EnterpriseIdentityRules.EnsureIdentifier(personId, nameof(personId));
        EnterpriseIdentityRules.EnsureIdentifier(linkedIdentityId, nameof(linkedIdentityId));
        if (PersonId is not null
            || LinkedIdentityId is not null
            || !Active
            || string.IsNullOrWhiteSpace(ETag))
        {
            throw new EnterpriseReplayException();
        }
        return this with
        {
            PersonId = personId,
            LinkedIdentityId = linkedIdentityId,
            UpdatedAt = updatedAt,
        };
    }

    public ScimProvisionedUser Deprovision(string organizationId, DateTimeOffset updatedAt)
    {
        EnsureOrganization(organizationId);
        if (PersonId is not null || LinkedIdentityId is not null)
        {
            throw new EnterpriseAtomicOffboardingRequiredException();
        }
        if (string.IsNullOrWhiteSpace(ETag))
        {
            throw new EnterpriseConcurrencyTokenException();
        }
        return !Active
            ? this
            : this with
            {
                Active = false,
                PersonId = null,
                LinkedIdentityId = null,
                UpdatedAt = updatedAt,
                DeprovisionedAt = updatedAt,
            };
    }

    public ScimDeprovisionPlan PlanDeprovision(
        string organizationId,
        OrganizationMembership membership,
        DateTimeOffset updatedAt)
    {
        EnsureOrganization(organizationId);
        if (!Active
            || PersonId is null
            || LinkedIdentityId is null
            || string.IsNullOrWhiteSpace(ETag)
            || string.IsNullOrWhiteSpace(membership.ETag)
            || !string.Equals(membership.OrganizationId, organizationId, StringComparison.Ordinal)
            || !string.Equals(membership.PersonId, PersonId, StringComparison.Ordinal)
            || !string.Equals(
                membership.Id,
                OrganizationDocumentIds.Membership(organizationId, PersonId),
                StringComparison.Ordinal))
        {
            throw new EnterpriseConcurrencyTokenException();
        }
        var deprovisioned = this with
        {
            Active = false,
            PersonId = null,
            LinkedIdentityId = null,
            UpdatedAt = updatedAt,
            DeprovisionedAt = updatedAt,
        };
        return new ScimDeprovisionPlan(
            organizationId,
            deprovisioned,
            ETag,
            membership,
            membership.ETag,
            OrganizationOffboardingTombstone.Create(membership, updatedAt));
    }

    private void EnsureOrganization(string organizationId)
    {
        if (!string.Equals(OrganizationId, organizationId, StringComparison.Ordinal))
        {
            throw new OrganizationNotFoundException();
        }
    }
}

public sealed record ScimDeprovisionPlan(
    string OrganizationId,
    ScimProvisionedUser DirectoryUser,
    string ExpectedDirectoryUserETag,
    OrganizationMembership Membership,
    string ExpectedMembershipETag,
    OrganizationOffboardingTombstone Tombstone);

public sealed record ScimProvisionedGroup(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string ExternalIdHash,
    string DisplayNameHash,
    IReadOnlyList<string> MemberExternalIdHashes,
    string RequestHash,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "scimProvisionedGroup";

    public static ScimProvisionedGroup Create(
        string organizationId,
        string externalId,
        string displayName,
        IEnumerable<string> memberExternalIds,
        string idempotencyKey,
        DateTimeOffset createdAt)
    {
        EnterpriseIdentityRules.EnsureIdentifier(organizationId, nameof(organizationId));
        EnterpriseIdentityRules.EnsureIdentifier(externalId, nameof(externalId));
        EnterpriseIdentityRules.EnsureIdentifier(displayName, nameof(displayName));
        EnterpriseIdentityRules.EnsureIdempotencyKey(idempotencyKey);
        var externalIdHash = EnterpriseIdentityDocumentIds.Hash(
            "certigo-scim-group-external-id:v1",
            organizationId,
            externalId);
        var memberHashes = memberExternalIds
            .Select(value =>
            {
                EnterpriseIdentityRules.EnsureIdentifier(value, nameof(memberExternalIds));
                return EnterpriseIdentityDocumentIds.Hash(
                    "certigo-scim-external-id:v1",
                    organizationId,
                    value);
            })
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();
        return new ScimProvisionedGroup(
            EnterpriseIdentityDocumentIds.ScimGroup(organizationId, externalIdHash),
            organizationId,
            CurrentSchemaVersion,
            Type,
            externalIdHash,
            EnterpriseIdentityDocumentIds.Hash(
                "certigo-scim-group-name:v1",
                organizationId,
                displayName),
            memberHashes,
            EnterpriseIdentityDocumentIds.Hash(
                "certigo-scim-group-request:v1",
                organizationId,
                externalIdHash,
                string.Join(",", memberHashes),
                idempotencyKey),
            createdAt,
            createdAt);
    }
}

public sealed record EnterpriseAuditEvent(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    EnterpriseAuditAction Action,
    string ActorHash,
    string TargetHash,
    string Outcome,
    DateTimeOffset OccurredAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "enterpriseAuditEvent";

    public static EnterpriseAuditEvent Create(
        string organizationId,
        EnterpriseAuditAction action,
        string actorId,
        string targetId,
        string outcome,
        DateTimeOffset occurredAt)
    {
        EnterpriseIdentityRules.EnsureIdentifier(organizationId, nameof(organizationId));
        EnterpriseIdentityRules.EnsureIdentifier(actorId, nameof(actorId));
        EnterpriseIdentityRules.EnsureIdentifier(targetId, nameof(targetId));
        if (!Enum.IsDefined(action) || outcome is not ("succeeded" or "rejected"))
        {
            throw new EnterpriseIdentityValidationException("Enterprise audit event is invalid.");
        }
        var actorHash = EnterpriseIdentityDocumentIds.Hash(
            "certigo-enterprise-audit-actor:v1",
            organizationId,
            actorId);
        var targetHash = EnterpriseIdentityDocumentIds.Hash(
            "certigo-enterprise-audit-target:v1",
            organizationId,
            targetId);
        return new EnterpriseAuditEvent(
            $"enterprise-audit::v1::{Guid.NewGuid():N}",
            organizationId,
            CurrentSchemaVersion,
            Type,
            action,
            actorHash,
            targetHash,
            outcome,
            occurredAt);
    }
}

public static class EnterpriseIdentityDocumentIds
{
    public static string Domain(string canonicalDomain) =>
        $"enterprise-domain::v1::{Hash("certigo-enterprise-domain:v1", canonicalDomain)}";

    public static string Federation(
        string organizationId,
        EnterpriseFederationProtocol protocol,
        string issuer) =>
        $"enterprise-federation::v1::{Hash(
            "certigo-enterprise-federation:v1",
            organizationId,
            protocol.ToString(),
            issuer)}";

    public static string ScimToken(string organizationId) =>
        $"scim-token::v1::{Hash("certigo-scim-token-document:v1", organizationId)}";

    public static string ScimUser(string organizationId, string externalIdHash) =>
        $"scim-user::v1::{Hash("certigo-scim-user:v1", organizationId, externalIdHash)}";

    public static string ScimGroup(string organizationId, string externalIdHash) =>
        $"scim-group::v1::{Hash("certigo-scim-group:v1", organizationId, externalIdHash)}";

    public static string Hash(params string[] values)
    {
        if (values.Any(string.IsNullOrWhiteSpace))
        {
            throw new EnterpriseIdentityValidationException("Hash inputs must not be blank.");
        }
        return Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(string.Join("\0", values))))
            .ToLowerInvariant();
    }

    internal static bool FixedTimeMatches(string expectedHash, params string[] values)
    {
        try
        {
            return CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(expectedHash),
                Convert.FromHexString(Hash(values)));
        }
        catch (FormatException)
        {
            return false;
        }
    }

    internal static bool FixedTimeEqualsHex(string left, string right)
    {
        try
        {
            return CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(left),
                Convert.FromHexString(right));
        }
        catch (FormatException)
        {
            return false;
        }
    }
}

internal static class EnterpriseIdentityRules
{
    public static void EnsureIdentifier(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value)
            || value != value.Trim()
            || value.Length > 320
            || value.Any(char.IsControl))
        {
            throw new EnterpriseIdentityValidationException($"{parameterName} is invalid.");
        }
    }

    public static void EnsureIdempotencyKey(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length is < 16 or > 200)
        {
            throw new EnterpriseIdentityValidationException(
                "Idempotency-Key must contain between 16 and 200 characters.");
        }
    }

    public static void EnsureSecret(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length < 32 || value.Length > 512)
        {
            throw new EnterpriseCredentialException();
        }
    }

    public static string CanonicalDomain(string domain)
    {
        EnsureIdentifier(domain, nameof(domain));
        var value = domain.Trim().TrimEnd('.').ToLowerInvariant();
        string ascii;
        try
        {
            ascii = new IdnMapping().GetAscii(value);
        }
        catch (ArgumentException)
        {
            throw new EnterpriseIdentityValidationException("The enterprise domain is invalid.");
        }
        var labels = ascii.Split('.');
        if (ascii.Length > 253
            || labels.Length < 2
            || labels.Any(label => label.Length is < 1 or > 63
                || label[0] == '-'
                || label[^1] == '-'
                || label.Any(character => !char.IsAsciiLetterOrDigit(character) && character != '-')))
        {
            throw new EnterpriseIdentityValidationException("The enterprise domain is invalid.");
        }
        return ascii;
    }
}

public sealed class EnterpriseIdentityValidationException(string message) : Exception(message);
public sealed class EnterpriseCredentialException()
    : Exception("The enterprise credential is invalid.");
public sealed class EnterpriseReplayException()
    : Exception("The enterprise operation was already consumed.");
public sealed class EnterpriseDomainChallengeExpiredException()
    : Exception("The enterprise domain challenge expired.");
public sealed class EnterpriseDomainAlreadyClaimedException()
    : Exception("The enterprise domain is already reserved.");
public sealed class EnterpriseConcurrencyTokenException()
    : Exception("The enterprise document requires a current concurrency token.");
public sealed class EnterpriseAtomicOffboardingRequiredException()
    : Exception("A bound SCIM user must be offboarded atomically with its membership.");
