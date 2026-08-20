using System.Globalization;
using System.Security.Claims;
using Certigo.Application.Abstractions;
using Certigo.Domain.Identity;

namespace Certigo.Api.Auth;

public sealed class FunctionLegacyIdentityObservationSource(IClock clock)
    : ILegacyIdentityObservationSource
{
    private const string MappedObjectIdentifierClaim =
        "http://schemas.microsoft.com/identity/claims/objectidentifier";
    private const string MappedTenantIdentifierClaim =
        "http://schemas.microsoft.com/identity/claims/tenantid";

    public LegacyIdentityObservation? Current
    {
        get
        {
            var principal = FunctionUserContext.Current.Value;
            if (principal is null)
            {
                return null;
            }

            var legacyUserId = principal.FindFirst("oid")?.Value
                ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? principal.FindFirst("sub")?.Value;
            var tenant = principal.FindFirst("tid")?.Value
                ?? principal.FindFirst(MappedTenantIdentifierClaim)?.Value;
            var objectId = principal.FindFirst("oid")?.Value
                ?? principal.FindFirst(MappedObjectIdentifierClaim)?.Value;
            if (string.IsNullOrWhiteSpace(legacyUserId)
                || string.IsNullOrWhiteSpace(tenant)
                || string.IsNullOrWhiteSpace(objectId))
            {
                // Local JWTs intentionally have no tid. Their opaque subject is
                // migrated only after a successful local authentication.
                return null;
            }

            IdentityLocator locator;
            try
            {
                locator = new IdentityLocator(
                    IdentityLocator.EntraProvider,
                    tenant,
                    objectId,
                    IdentityLocator.EntraExternalIdType).EnsureCanonical();
            }
            catch (InvalidIdentityLocatorException)
            {
                return null;
            }

            var authenticatedAt = UnixTimeClaim(principal, "auth_time")
                ?? UnixTimeClaim(principal, "iat")
                ?? clock.UtcNow;
            return new LegacyIdentityObservation(
                legacyUserId,
                locator,
                new LinkedIdentityVerification(
                    LinkedIdentityVerification.VerifiedState,
                    LinkedIdentityVerification.OidcReauthenticationMethod,
                    clock.UtcNow,
                    authenticatedAt,
                    principal.FindFirst("iss")?.Value,
                    principal.FindFirst("aud")?.Value));
        }
    }

    private static DateTimeOffset? UnixTimeClaim(
        ClaimsPrincipal principal,
        string claimType)
    {
        var raw = principal.FindFirst(claimType)?.Value;
        return long.TryParse(
            raw,
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out var seconds)
            ? DateTimeOffset.FromUnixTimeSeconds(seconds)
            : null;
    }
}
