namespace Certigo.VivaLearning.Poc;

public static class VivaLearningPocGate
{
    public const string FeatureFlag = "CERTIGO_VIVA_LEARNING_POC_ENABLED";

    public static bool IsEnabled(string? value)
        => string.Equals(value?.Trim(), "true", StringComparison.OrdinalIgnoreCase);
}

public sealed class VivaLearningPocScenario(
    IVivaLearningGraphClient graphClient,
    CertigoVivaLearningAdapter adapter)
{
    public async Task<VivaLearningPocScenarioResult> RunAsync(
        DateTimeOffset observedAt,
        CancellationToken cancellationToken = default)
    {
        var provider = await graphClient.RegisterProviderAsync(
            new LearningProviderWriteDto
            {
                DisplayName = "Certigo POC",
                SquareLogoWebUrlForDarkTheme = "https://certigo.invalid/assets/logo-square-dark.png",
                LongLogoWebUrlForDarkTheme = "https://certigo.invalid/assets/logo-long-dark.png",
                SquareLogoWebUrlForLightTheme = "https://certigo.invalid/assets/logo-square-light.png",
                LongLogoWebUrlForLightTheme = "https://certigo.invalid/assets/logo-long-light.png",
                LoginWebUrl = "https://certigo.invalid/sign-in",
                IsCourseActivitySyncEnabled = true
            },
            cancellationToken);

        var contentWrite = adapter.ToLearningContent(new CertigoLessonDescriptor(
            "az-900",
            "az900-l-cloud-benefits",
            "Benefices du cloud",
            "Lecon Certigo de preuve de concept Viva Learning.",
            5,
            "fr-fr",
            "fundamentals",
            observedAt));
        var content = await graphClient.PublishContentAsync(
            provider.Id,
            contentWrite,
            cancellationToken);
        var mapping = CertigoVivaLearningAdapter.ToPublishedMapping(provider.Id, content);

        var assignments = await graphClient.ListMyAssignmentsAsync(cancellationToken);
        var assignment = assignments.Single(item =>
            string.Equals(item.LearningProviderId, provider.Id, StringComparison.Ordinal)
            && string.Equals(item.LearningContentId, content.Id, StringComparison.Ordinal));
        var deepLink = CertigoVivaLearningAdapter.ResolveAssignmentDeepLink(assignment, mapping);

        var inProgress = CertigoVivaLearningAdapter.ToAssignmentProgress(40, observedAt);
        await graphClient.SyncAssignmentProgressAsync(
            provider.Id,
            assignment.Id,
            inProgress,
            cancellationToken);

        var completed = CertigoVivaLearningAdapter.ToAssignmentProgress(
            100,
            observedAt.AddMinutes(5));
        await graphClient.SyncAssignmentProgressAsync(
            provider.Id,
            assignment.Id,
            completed,
            cancellationToken);

        return new VivaLearningPocScenarioResult(
            provider,
            content,
            assignment,
            deepLink,
            inProgress,
            completed);
    }
}
