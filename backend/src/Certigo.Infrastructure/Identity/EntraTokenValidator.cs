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
    private const string ApplicationIdUriPrefix = "api://";

    private readonly IReadOnlyList<string> _audiences;
    private readonly string _issuer;
    private readonly ILogger<EntraTokenValidator> _logger;
    private readonly IConfigurationManager<OpenIdConnectConfiguration> _configurationManager;
    private readonly JwtSecurityTokenHandler _handler = new();

    public EntraTokenValidator(string authority, string audience, ILogger<EntraTokenValidator>? logger = null)
        : this(authority, audience, configurationManager: null, logger)
    {
    }

    internal EntraTokenValidator(
        string authority,
        string audience,
        IConfigurationManager<OpenIdConnectConfiguration>? configurationManager,
        ILogger<EntraTokenValidator>? logger = null)
    {
        if (string.IsNullOrWhiteSpace(authority))
        {
            throw new ArgumentException("ENTRA_AUTHORITY is required.", nameof(authority));
        }

        _audiences = !string.IsNullOrWhiteSpace(audience)
            ? AcceptedAudiences(audience.Trim())
            : throw new ArgumentException("ENTRA_AUDIENCE is required.", nameof(audience));
        _issuer = authority.TrimEnd('/');
        _logger = logger ?? NullLogger<EntraTokenValidator>.Instance;
        _configurationManager = configurationManager
            ?? new ConfigurationManager<OpenIdConnectConfiguration>(
                $"{_issuer}/.well-known/openid-configuration",
                new OpenIdConnectConfigurationRetriever());
    }

    /// Entra v2 access tokens always carry the API's client id as <c>aud</c>, whereas
    /// v1 tokens carry the requested Application ID URI (<c>api://{client id}</c>). Both
    /// spellings name the same API registration, so both are accepted — the default of
    /// Microsoft.Identity.Web. Any other audience, issuer or signing key is still rejected.
    internal static IReadOnlyList<string> AcceptedAudiences(string audience)
    {
        if (audience.StartsWith(ApplicationIdUriPrefix, StringComparison.OrdinalIgnoreCase)
            && Guid.TryParseExact(audience[ApplicationIdUriPrefix.Length..], "D", out var uriClientId))
        {
            return [audience, uriClientId.ToString("D")];
        }

        return Guid.TryParseExact(audience, "D", out var clientId)
            ? [audience, $"{ApplicationIdUriPrefix}{clientId:D}"]
            : [audience];
    }

    public async Task<AppTokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default)
    {
        try
        {
            var config = await _configurationManager.GetConfigurationAsync(cancellationToken);
            var principal = _handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidAudiences = _audiences,
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
