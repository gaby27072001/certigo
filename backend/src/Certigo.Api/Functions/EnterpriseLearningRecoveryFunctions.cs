using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Timer;

namespace Certigo.Api.Functions;

public sealed class EnterpriseLearningRecoveryFunctions(
    EnterpriseLearningMetricsFeatureOptions options,
    IEnterpriseLearningReceiptOutboxWorker receiptOutbox,
    IOrganizationOffboardingRecoveryWorker offboarding)
{
    private const int MaximumBatchSize = 50;

    [Function("RecoverEnterpriseLearningMetricsV1")]
    public async Task RunAsync(
        [TimerTrigger(
            "%ENTERPRISE_LEARNING_RECOVERY_SCHEDULE%",
            RunOnStartup = false)]
        TimerInfo timer,
        CancellationToken cancellationToken)
    {
        _ = timer;
        if (options.Mode == EnterpriseLearningMetricsFeatureMode.Off)
        {
            return;
        }
        await receiptOutbox.RunBatchAsync(MaximumBatchSize, cancellationToken);
        await offboarding.RunBatchAsync(MaximumBatchSize, cancellationToken);
    }
}
