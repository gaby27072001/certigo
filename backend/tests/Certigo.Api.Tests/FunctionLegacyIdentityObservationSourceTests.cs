using System.Security.Claims;
using Certigo.Api.Auth;
using Certigo.Application.Abstractions;
using Certigo.Domain.Identity;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class FunctionLegacyIdentityObservationSourceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Validated_entra_claims_produce_tid_oid_observation_without_email()
    {
        var identity = new ClaimsIdentity(
        [
            new Claim("oid", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            new Claim("tid", "11111111-1111-4111-8111-aaaaaaaaaaaa"),
            new Claim("iss", "https://issuer.example"),
            new Claim("aud", "api://certigo"),
            new Claim("auth_time", Now.AddMinutes(-2).ToUnixTimeSeconds().ToString()),
            new Claim("email", "shared@example.com"),
        ], "test");
        FunctionUserContext.Current.Value = new ClaimsPrincipal(identity);
        try
        {
            var observation = new FunctionLegacyIdentityObservationSource(
                new FixedClock(Now)).Current;

            observation.Should().NotBeNull();
            observation!.LegacyUserId.Should()
                .Be("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
            observation.Locator.Provider.Should().Be(IdentityLocator.EntraProvider);
            observation.Locator.Tenant.Should()
                .Be("11111111-1111-4111-8111-aaaaaaaaaaaa");
            observation.Locator.Subject.Should()
                .Be("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
            observation.Verification.AuthenticatedAt.Should().Be(Now.AddMinutes(-2));
            observation.GetType().GetProperties().Select(property => property.Name)
                .Should().NotContain("Email");
        }
        finally
        {
            FunctionUserContext.Current.Value = null;
        }
    }

    [Fact]
    public void Local_or_incomplete_claims_stay_on_the_legacy_path()
    {
        FunctionUserContext.Current.Value = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim("oid", "local-user"),
            new Claim("email", "local@example.com"),
        ], "test"));
        try
        {
            new FunctionLegacyIdentityObservationSource(new FixedClock(Now))
                .Current.Should().BeNull();
        }
        finally
        {
            FunctionUserContext.Current.Value = null;
        }
    }

    [Fact]
    public void Mapped_entra_claim_types_preserve_the_legacy_owner_and_oid_locator()
    {
        FunctionUserContext.Current.Value = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, "legacy-subject-owner"),
            new Claim(
                "http://schemas.microsoft.com/identity/claims/objectidentifier",
                "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            new Claim(
                "http://schemas.microsoft.com/identity/claims/tenantid",
                "11111111-1111-4111-8111-aaaaaaaaaaaa"),
        ], "test"));
        try
        {
            var observation = new FunctionLegacyIdentityObservationSource(
                new FixedClock(Now)).Current;

            observation.Should().NotBeNull();
            observation!.LegacyUserId.Should().Be("legacy-subject-owner");
            observation.Locator.Subject.Should()
                .Be("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
            observation.Locator.Tenant.Should()
                .Be("11111111-1111-4111-8111-aaaaaaaaaaaa");
        }
        finally
        {
            FunctionUserContext.Current.Value = null;
        }
    }

    private sealed class FixedClock(DateTimeOffset now) : IClock
    {
        public DateTimeOffset UtcNow { get; } = now;
    }
}
