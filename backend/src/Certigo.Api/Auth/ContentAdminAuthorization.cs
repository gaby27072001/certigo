using System.Security.Claims;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;

namespace Certigo.Api.Auth;

public sealed class ContentAdminAuthorization(string requiredRole, bool allowDevIdentity)
{
    public string Require(FunctionContext context)
    {
        var principal = context.Items.TryGetValue("User", out var value)
            ? value as ClaimsPrincipal
            : null;
        if (principal is null)
        {
            throw new UnauthorizedAccessException("No authenticated user is available.");
        }

        var hasRole = principal.Claims.Any(claim =>
            claim.Type is "roles" or ClaimTypes.Role
            && string.Equals(claim.Value, requiredRole, StringComparison.Ordinal));
        var isAllowedDevIdentity = allowDevIdentity
            && string.Equals(principal.Identity?.AuthenticationType, "dev", StringComparison.Ordinal);
        if (!hasRole && !isAllowedDevIdentity)
        {
            throw new ContentAccessForbiddenException(
                $"The '{requiredRole}' application role is required.");
        }

        return principal.FindFirst("oid")?.Value
               ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value
               ?? principal.FindFirst("sub")?.Value
               ?? throw new ContentAccessForbiddenException("The administrator identity has no stable id.");
    }
}
