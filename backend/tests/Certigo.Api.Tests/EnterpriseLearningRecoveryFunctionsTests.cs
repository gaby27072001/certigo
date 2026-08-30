using Certigo.Api.Functions;
using Certigo.Application.Abstractions;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class EnterpriseLearningRecoveryFunctionsTests
{
    [Fact]
    public async Task Timer_is_a_strict_no_op_while_feature_is_off()
    {
        var receipts = new SpyReceiptWorker();
        var offboarding = new SpyOffboardingWorker();
        var function = new EnterpriseLearningRecoveryFunctions(
            EnterpriseLearningMetricsFeatureOptions.Parse(null),
            receipts,
            offboarding);

        await function.RunAsync(null!, CancellationToken.None);

        receipts.CallCount.Should().Be(0);
        offboarding.CallCount.Should().Be(0);
    }

    private sealed class SpyReceiptWorker : IEnterpriseLearningReceiptOutboxWorker
    {
        public int CallCount { get; private set; }

        public Task<int> RunBatchAsync(
            int maximumIntents,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(0);
        }
    }

    private sealed class SpyOffboardingWorker : IOrganizationOffboardingRecoveryWorker
    {
        public int CallCount { get; private set; }

        public Task<int> RunBatchAsync(
            int maximumTombstones,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(0);
        }
    }
}
