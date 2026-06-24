using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using Microlingo.Application.Abstractions;

namespace Microlingo.Infrastructure.Identity;

/// Shared key derivation for the locally-issued HS256 tokens. The configured
/// secret is hashed to a fixed 256-bit key so any secret length yields a key
/// large enough for HMAC-SHA256.
internal static class LocalJwtSigning
{
    public static SymmetricSecurityKey DeriveKey(string secret) =>
        new(SHA256.HashData(Encoding.UTF8.GetBytes(secret ?? string.Empty)));

    /// Claims map 1:1 to short JWT claim names (no inbound/outbound transform),
    /// matching what <see cref="Microlingo.Application.Abstractions.IUserContext"/>
    /// reads (oid / name / email).
    public static JwtSecurityTokenHandler CreateHandler() => new() { MapInboundClaims = false };

    public const string RefreshMarkerClaim = "typ";
    public const string RefreshMarkerValue = "refresh";
}

/// Mints and validates the locally-signed JWTs that back email/password sessions.
/// Access tokens carry oid/name/email so a learner who signed up with an email is
/// indistinguishable from an Entra user downstream; refresh tokens additionally
/// carry a <c>typ=refresh</c> marker and are only honoured by <see cref="ValidateRefreshToken"/>.
public sealed class JwtTokenIssuer : ITokenIssuer
{
    private readonly SymmetricSecurityKey _key;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly TimeSpan _accessLifetime;
    private readonly TimeSpan _refreshLifetime;
    private readonly JwtSecurityTokenHandler _handler = LocalJwtSigning.CreateHandler();

    public JwtTokenIssuer(
        string signingSecret,
        string issuer,
        string audience,
        TimeSpan? accessLifetime = null,
        TimeSpan? refreshLifetime = null)
    {
        _key = LocalJwtSigning.DeriveKey(signingSecret);
        _issuer = string.IsNullOrWhiteSpace(issuer) ? "microlingo" : issuer;
        _audience = string.IsNullOrWhiteSpace(audience) ? "microlingo" : audience;
        _accessLifetime = accessLifetime ?? TimeSpan.FromDays(1);
        _refreshLifetime = refreshLifetime ?? TimeSpan.FromDays(90);
    }

    public IssuedTokens Issue(string userId, string displayName, string email)
    {
        var now = DateTime.UtcNow;
        var accessExpires = now.Add(_accessLifetime);
        var access = Write(userId, displayName, email, now, accessExpires, isRefresh: false);
        var refresh = Write(userId, displayName, email, now, now.Add(_refreshLifetime), isRefresh: true);
        return new IssuedTokens(access, refresh, accessExpires);
    }

    public RefreshTokenPrincipal? ValidateRefreshToken(string refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return null;
        }

        try
        {
            var principal = _handler.ValidateToken(refreshToken, ValidationParameters(), out _);
            if (principal.FindFirst(LocalJwtSigning.RefreshMarkerClaim)?.Value != LocalJwtSigning.RefreshMarkerValue)
            {
                return null; // an access token presented as a refresh token
            }

            var userId = principal.FindFirst("oid")?.Value;
            if (string.IsNullOrWhiteSpace(userId))
            {
                return null;
            }

            var name = principal.FindFirst("name")?.Value ?? "Microlingo learner";
            var email = principal.FindFirst("email")?.Value ?? string.Empty;
            return new RefreshTokenPrincipal(userId, name, email);
        }
        catch
        {
            return null;
        }
    }

    private string Write(string userId, string displayName, string email, DateTime issuedAt, DateTime expires, bool isRefresh)
    {
        var claims = new List<Claim>
        {
            new("oid", userId),
            new("sub", userId),
            new("name", string.IsNullOrWhiteSpace(displayName) ? "Microlingo learner" : displayName),
        };
        if (!string.IsNullOrWhiteSpace(email))
        {
            claims.Add(new Claim("email", email));
        }

        if (isRefresh)
        {
            claims.Add(new Claim(LocalJwtSigning.RefreshMarkerClaim, LocalJwtSigning.RefreshMarkerValue));
        }

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            notBefore: issuedAt,
            expires: expires,
            signingCredentials: new SigningCredentials(_key, SecurityAlgorithms.HmacSha256));
        return _handler.WriteToken(token);
    }

    private TokenValidationParameters ValidationParameters() => new()
    {
        ValidIssuer = _issuer,
        ValidAudience = _audience,
        IssuerSigningKey = _key,
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateIssuerSigningKey = true,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromMinutes(2)
    };
}
