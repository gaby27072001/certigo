using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using Microlingo.Application.Abstractions;
using AppTokenValidationResult = Microlingo.Application.Abstractions.TokenValidationResult;

namespace Microlingo.Infrastructure.Identity;

public sealed class EntraTokenValidator : ITokenValidator
{
    private readonly string _audience;
    private readonly string _issuer;
    private readonly ConfigurationManager<OpenIdConnectConfiguration> _configurationManager;
    private readonly JwtSecurityTokenHandler _handler = new();

    public EntraTokenValidator(string authority, string audience)
    {
        if (string.IsNullOrWhiteSpace(authority))
        {
            throw new ArgumentException("ENTRA_AUTHORITY is required.", nameof(authority));
        }

        _audience = !string.IsNullOrWhiteSpace(audience)
            ? audience
            : throw new ArgumentException("ENTRA_AUDIENCE is required.", nameof(audience));
        _issuer = authority.TrimEnd('/');
        _configurationManager = new ConfigurationManager<OpenIdConnectConfiguration>(
            $"{_issuer}/.well-known/openid-configuration",
            new OpenIdConnectConfigurationRetriever());
    }

    public async Task<AppTokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default)
    {
        try
        {
            var config = await _configurationManager.GetConfigurationAsync(cancellationToken);
            var principal = _handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidAudience = _audience,
                ValidIssuer = config.Issuer,
                IssuerSigningKeys = config.SigningKeys,
                ValidateAudience = true,
                ValidateIssuer = true,
                ValidateIssuerSigningKey = true,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(2)
            }, out _);

            var userId = principal.FindFirst("oid")?.Value
                ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? principal.FindFirst("sub")?.Value;
            return string.IsNullOrWhiteSpace(userId)
                ? new AppTokenValidationResult(false, null, null)
                : new AppTokenValidationResult(true, principal, userId);
        }
        catch
        {
            return new AppTokenValidationResult(false, null, null);
        }
    }
}
