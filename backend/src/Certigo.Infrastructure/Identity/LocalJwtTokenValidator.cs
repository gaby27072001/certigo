using System.Security.Claims;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
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
    private readonly ILogger<LocalJwtTokenValidator> _logger;
    private readonly JwtSecurityTokenHandler _handler = LocalJwtSigning.CreateHandler();

    public LocalJwtTokenValidator(
        string signingSecret,
        string issuer,
        string audience,
        ILogger<LocalJwtTokenValidator>? logger = null)
    {
        _key = LocalJwtSigning.DeriveKey(signingSecret);
        _issuer = string.IsNullOrWhiteSpace(issuer) ? "certigo" : issuer;
        _audience = string.IsNullOrWhiteSpace(audience) ? "certigo" : audience;
        _logger = logger ?? NullLogger<LocalJwtTokenValidator>.Instance;
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
                // A refresh token was presented as an access token: a validation
                // failure, not a fault. The token itself is never logged.
                _logger.LogInformation(
                    "Local JWT validation rejected a refresh token presented as an access token.");
                return Task.FromResult(new AppTokenValidationResult(false, null, null));
            }

            var userId = principal.FindFirst("oid")?.Value
                ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? principal.FindFirst("sub")?.Value;
            return Task.FromResult(string.IsNullOrWhiteSpace(userId)
                ? new AppTokenValidationResult(false, null, null)
                : new AppTokenValidationResult(true, principal, userId));
        }
        catch (Exception ex) when (ex is SecurityTokenException or ArgumentException)
        {
            // Expected rejection of an invalid/expired/foreign token. Logged at
            // Information (this validator is tried first for every request, so an
            // Entra-issued token legitimately fails here). Only the error type and
            // message are logged — never the token or any of its claims.
            _logger.LogInformation(
                "Local JWT validation rejected a token: {ErrorType} - {ErrorMessage}",
                ex.GetType().Name,
                ex.Message);
            return Task.FromResult(new AppTokenValidationResult(false, null, null));
        }
        catch (Exception ex)
        {
            // Unexpected/transient failure (e.g. crypto). Surfaced at Warning so it is
            // not silently swallowed, while validation still fails closed. The token is
            // never logged.
            _logger.LogWarning(
                ex,
                "Local JWT validation failed unexpectedly ({ErrorType}); treating the token as invalid.",
                ex.GetType().Name);
            return Task.FromResult(new AppTokenValidationResult(false, null, null));
        }
    }
}
