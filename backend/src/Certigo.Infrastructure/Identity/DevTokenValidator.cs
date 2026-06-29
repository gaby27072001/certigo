using System.Security.Claims;
using Certigo.Application.Abstractions;
using AppTokenValidationResult = Certigo.Application.Abstractions.TokenValidationResult;

namespace Certigo.Infrastructure.Identity;

/// A deliberately permissive token validator for local development and CI smoke
/// tests. It is only registered when <c>AUTH_MODE=dev</c>; never wire it up in a
/// production deployment. The bearer token is treated as the user id so a tester
/// can act as any user by sending <c>Authorization: Bearer &lt;userId&gt;</c>.
public sealed class DevTokenValidator : ITokenValidator
{
    public Task<AppTokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default)
    {
        var userId = string.IsNullOrWhiteSpace(token) || token.Equals("dev", StringComparison.OrdinalIgnoreCase)
            ? "dev-user"
            : token.Trim();

        var identity = new ClaimsIdentity("dev");
        identity.AddClaim(new Claim("oid", userId));
        identity.AddClaim(new Claim("name", $"Dev {userId}"));
        var principal = new ClaimsPrincipal(identity);
        return Task.FromResult(new AppTokenValidationResult(true, principal, userId));
    }
}
