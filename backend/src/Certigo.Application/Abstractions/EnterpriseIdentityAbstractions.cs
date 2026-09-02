using Certigo.Domain.Organizations;

namespace Certigo.Application.Abstractions;

public enum EnterpriseIdentityFeatureMode
{
    Off,
}

public sealed record EnterpriseIdentityFeatureOptions(EnterpriseIdentityFeatureMode Mode)
{
    public static EnterpriseIdentityFeatureOptions Parse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)
            || string.Equals(value.Trim(), "off", StringComparison.OrdinalIgnoreCase))
        {
            return new EnterpriseIdentityFeatureOptions(EnterpriseIdentityFeatureMode.Off);
        }

        throw new InvalidOperationException(
            "ENTERPRISE_IDENTITY_V1 only supports 'off' in this contract increment.");
    }
}

public sealed class EnterpriseIdentityFeatureDisabledException()
    : Exception("The enterprise identity V1 surface is disabled.");

public interface IEnterpriseDomainClaimRepository
{
    Task ReserveAsync(
        EnterpriseDomainClaim claim,
        CancellationToken cancellationToken = default);

    Task ConfirmAsync(
        EnterpriseDomainClaim claim,
        string expectedETag,
        CancellationToken cancellationToken = default);

    Task ReleaseAsync(
        EnterpriseDomainClaim claim,
        string expectedETag,
        CancellationToken cancellationToken = default);
}

public interface IEnterpriseScimProvisioningRepository
{
    Task CommitDeprovisionAsync(
        ScimDeprovisionPlan plan,
        CancellationToken cancellationToken = default);
}
