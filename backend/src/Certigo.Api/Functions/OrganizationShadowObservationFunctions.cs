using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Timer;

namespace Certigo.Api.Functions;

/// <summary>
/// Strictly read-only shadow observation for Organization/Membership. The constructor depends
/// only on <see cref="IOrganizationShadowObservationReader"/> — never on the full
/// <see cref="IOrganizationRepository"/> nor on <c>IOrganizationOffboardingRecoveryWorker</c> —
/// so this Function is structurally incapable of creating, replacing, or deleting any
/// Organization/Membership document. It only lists incomplete offboardings and counts team
/// memberships; the repository itself records non-PII telemetry (RU, counts) for both calls. A
/// strict no-op unless the feature is exactly <see cref="OrganizationFeatureMode.Shadow"/> — it
/// never runs while <see cref="OrganizationFeatureMode.Off"/> (the default in every environment).
/// </summary>
public sealed class OrganizationShadowObservationFunctions(
    OrganizationFeatureOptions options,
    IOrganizationShadowObservationReader observations)
{
    private const int MaximumTombstonesObserved = 50;

    [Function("ObserveOrganizationMembershipShadowV1")]
    public async Task RunAsync(
        [TimerTrigger(
            "%ORGANIZATION_SHADOW_OBSERVATION_SCHEDULE%",
            RunOnStartup = false)]
        TimerInfo timer,
        CancellationToken cancellationToken)
    {
        _ = timer;
        if (options.Mode != OrganizationFeatureMode.Shadow)
        {
            return;
        }

        await observations.ListIncompleteOffboardingsAsync(
            MaximumTombstonesObserved,
            cancellationToken);
        await observations.CountTeamMembershipsAsync(cancellationToken);
    }
}
