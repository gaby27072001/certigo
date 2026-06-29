using System.Security.Claims;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;
using Certigo.Application.Abstractions;
using AppTokenValidationResult = Certigo.Application.Abstractions.TokenValidationResult;

namespace Certigo.Infrastructure.Identity;

/// Validates the locally-signed access tokens issued by <see cref="JwtTokenIssuer"/>
/// for email/password sessions. Refresh tokens (carrying <c>typ=refresh</c>) are
/// explicitly rejected here so they can never be used to call the API directly.
public sealed class LocalJwtTokenValidator : ITokenValidator
{
    private readonly SymmetricSecurityKey _key;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly JwtSecurityTokenHandler _handler = LocalJwtSigning.CreateHandler();

    public LocalJwtTokenValidator(string signingSecret, string issuer, string audience)
    {
        _key = LocalJwtSigning.DeriveKey(signingSecret);
        _issuer = string.IsNullOrWhiteSpace(issuer) ? "certigo" : issuer;
        _audience = string.IsNullOrWhiteSpace(audience) ? "certigo" : audience;
    }

    public Task<AppTokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default)
    {
        try
        {
            var principal = _handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidIssuer = _issuer,
                ValidAudience = _audience,
                IssuerSigningKey = _key,
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateIssuerSigningKey = true,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(2)
            }, out _);

            if (principal.FindFirst(LocalJwtSigning.RefreshMarkerClaim)?.Value == LocalJwtSigning.RefreshMarkerValue)
            {
                return Task.FromResult(new AppTokenValidationResult(false, null, null));
            }

            var userId = principal.FindFirst("oid")?.Value
                ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? principal.FindFirst("sub")?.Value;
            return Task.FromResult(string.IsNullOrWhiteSpace(userId)
                ? new AppTokenValidationResult(false, null, null)
                : new AppTokenValidationResult(true, principal, userId));
        }
        catch
        {
            return Task.FromResult(new AppTokenValidationResult(false, null, null));
        }
    }
}
