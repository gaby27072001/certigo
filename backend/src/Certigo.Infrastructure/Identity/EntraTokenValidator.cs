using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using Certigo.Application.Abstractions;
using AppTokenValidationResult = Certigo.Application.Abstractions.TokenValidationResult;

namespace Certigo.Infrastructure.Identity;

public sealed class EntraTokenValidator : ITokenValidator
{
    private readonly string _audience;
    private readonly string _issuer;
    private readonly ILogger<EntraTokenValidator> _logger;
    private readonly ConfigurationManager<OpenIdConnectConfiguration> _configurationManager;
    private readonly JwtSecurityTokenHandler _handler = new();

    public EntraTokenValidator(string authority, string audience, ILogger<EntraTokenValidator>? logger = null)
    {
        if (string.IsNullOrWhiteSpace(authority))
        {
            throw new ArgumentException("ENTRA_AUTHORITY is required.", nameof(authority));
        }

        _audience = !string.IsNullOrWhiteSpace(audience)
            ? audience
            : throw new ArgumentException("ENTRA_AUDIENCE is required.", nameof(audience));
        _issuer = authority.TrimEnd('/');
        _logger = logger ?? NullLogger<EntraTokenValidator>.Instance;
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
                RoleClaimType = "roles",
                ClockSkew = TimeSpan.FromMinutes(2)
            }, out _);

            var userId = principal.FindFirst("oid")?.Value
                ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? principal.FindFirst("sub")?.Value;
            return string.IsNullOrWhiteSpace(userId)
                ? new AppTokenValidationResult(false, null, null)
                : new AppTokenValidationResult(true, principal, userId);
        }
        catch (Exception ex) when (ex is SecurityTokenException or ArgumentException)
        {
            // Expected rejection of an invalid/expired token. Logged at Information;
            // only the error type and message are recorded, never the token or claims.
            _logger.LogInformation(
                "Entra token validation rejected a token: {ErrorType} - {ErrorMessage}",
                ex.GetType().Name,
                ex.Message);
            return new AppTokenValidationResult(false, null, null);
        }
        catch (Exception ex)
        {
            // Transient/unexpected failure (network, OpenID configuration retrieval,
            // signing-key discovery). Surfaced at Warning so it is not silently
            // swallowed, while validation still fails closed. The token is never logged.
            _logger.LogWarning(
                ex,
                "Entra token validation failed to complete ({ErrorType}); treating the token as invalid. "
                + "This may indicate a transient network or OpenID configuration problem.",
                ex.GetType().Name);
            return new AppTokenValidationResult(false, null, null);
        }
    }
}
