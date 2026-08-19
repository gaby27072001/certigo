using System.Text.Json;
using Certigo.VivaLearning.Poc;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class VivaLearningPocContractTests
{
    private static readonly DateTimeOffset ObservedAt =
        new(2026, 8, 19, 12, 15, 0, TimeSpan.Zero);

    [Fact]
    public async Task Feature_flag_blocks_all_requests_when_disabled()
    {
        var handler = new FixtureGraphMessageHandler(FixtureDirectory());
        using var httpClient = new HttpClient(handler);
        var client = new VivaLearningGraphClient(
            httpClient,
            new VivaLearningPocOptions(
                Enabled: false,
                GraphBaseUri: new Uri("https://graph.microsoft.com/v1.0/")));

        var act = async () => await client.ListMyAssignmentsAsync();

        await act.Should().ThrowAsync<VivaLearningGraphException>()
            .WithMessage($"*{VivaLearningPocGate.FeatureFlag}*");
        handler.Requests.Should().BeEmpty();
        VivaLearningPocGate.IsEnabled(null).Should().BeFalse();
        VivaLearningPocGate.IsEnabled("false").Should().BeFalse();
        VivaLearningPocGate.IsEnabled("true").Should().BeTrue();
    }

    [Fact]
    public void Operation_catalog_keeps_endpoint_specific_auth_boundaries()
    {
        VivaLearningOperationContract.All.Should().BeEquivalentTo(
            [
                new
                {
                    Operation = "Register provider",
                    AuthMode = VivaLearningAuthMode.DelegatedAdministrator,
                    Permission = "LearningProvider.ReadWrite"
                },
                new
                {
                    Operation = "Publish content",
                    AuthMode = VivaLearningAuthMode.Application,
                    Permission = "LearningContent.ReadWrite.All"
                },
                new
                {
                    Operation = "Read my assignments",
                    AuthMode = VivaLearningAuthMode.DelegatedUser,
                    Permission = "LearningAssignedCourse.Read.All"
                },
                new
                {
                    Operation = "Sync assignment progress",
                    AuthMode = VivaLearningAuthMode.Application,
                    Permission = "LearningAssignedCourse.ReadWrite.All"
                }
            ],
            options => options.WithStrictOrdering());
    }

    [Theory]
    [InlineData("http://graph.microsoft.com/v1.0/")]
    [InlineData("https://graph.microsoft.com/beta/")]
    [InlineData("https://example.invalid/v1.0/")]
    public void Graph_client_rejects_non_v1_graph_endpoints(string endpoint)
    {
        using var httpClient = new HttpClient(new FixtureGraphMessageHandler(FixtureDirectory()));

        var act = () => new VivaLearningGraphClient(
            httpClient,
            new VivaLearningPocOptions(true, new Uri(endpoint)));

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Adapter_maps_certigo_lesson_to_existing_router_path()
    {
        var adapter = new CertigoVivaLearningAdapter(new Uri("https://certigo.invalid/"));

        var content = adapter.ToLearningContent(new CertigoLessonDescriptor(
            "az-900",
            "az900-l-cloud-benefits",
            "Benefices du cloud",
            "Description",
            5,
            "fr-fr",
            "fundamentals",
            ObservedAt));

        content.ExternalId.Should().Be("certigo:az-900:az900-l-cloud-benefits");
        content.ContentWebUrl.Should()
            .Be("https://certigo.invalid/lesson/az-900/az900-l-cloud-benefits");
        content.Duration.Should().Be("PT5M");
        content.Level.Should().Be("Beginner");
        content.IsPremium.Should().BeTrue();
    }

    [Fact]
    public async Task Offline_scenario_proves_provider_content_assignment_link_and_progress_contracts()
    {
        var handler = new FixtureGraphMessageHandler(FixtureDirectory());
        using var httpClient = new HttpClient(handler);
        var client = new VivaLearningGraphClient(
            httpClient,
            new VivaLearningPocOptions(
                Enabled: true,
                GraphBaseUri: new Uri("https://graph.microsoft.com/v1.0/")));
        var scenario = new VivaLearningPocScenario(
            client,
            new CertigoVivaLearningAdapter(new Uri("https://certigo.invalid/")));

        var result = await scenario.RunAsync(ObservedAt);

        result.Provider.Id.Should().Be("11111111-1111-1111-1111-111111111111");
        result.Content.Id.Should().Be("22222222-2222-2222-2222-222222222222");
        result.Assignment.Id.Should().Be("33333333-3333-3333-3333-333333333333");
        result.DeepLink.AbsoluteUri.Should()
            .Be("https://certigo.invalid/lesson/az-900/az900-l-cloud-benefits");
        result.InProgress.Status.Should().Be("inProgress");
        result.Completed.Status.Should().Be("completed");
        result.Completed.CompletedDateTime.Should().Be(ObservedAt.AddMinutes(5));

        handler.Requests.Should().HaveCount(5);
        handler.Requests.Select(request => request.Method).Should().ContainInOrder(
            "POST",
            "PATCH",
            "GET",
            "PATCH",
            "PATCH");

        var providerRequest = handler.Requests[0];
        providerRequest.PathAndQuery.Should().Be("/v1.0/employeeExperience/learningProviders");
        ReadBody(providerRequest).GetProperty("isCourseActivitySyncEnabled").GetBoolean()
            .Should().BeTrue();

        var contentRequest = handler.Requests[1];
        contentRequest.PathAndQuery.Should().Contain(
            "/v1.0/employeeExperience/learningProviders/11111111-1111-1111-1111-111111111111/"
            + "learningContents(externalId=");
        var contentBody = ReadBody(contentRequest);
        contentBody.GetProperty("externalId").GetString().Should()
            .Be("certigo:az-900:az900-l-cloud-benefits");
        contentBody.GetProperty("contentWebUrl").GetString().Should()
            .Be("https://certigo.invalid/lesson/az-900/az900-l-cloud-benefits");
        contentBody.GetProperty("isPremium").GetBoolean().Should().BeTrue();

        var assignmentRequest = handler.Requests[2];
        assignmentRequest.PathAndQuery.Should()
            .Be("/v1.0/me/employeeExperience/learningCourseActivities");
        assignmentRequest.Headers["Prefer"].Should().Contain("include-unknown-enum-members");

        var progressBody = ReadBody(handler.Requests[3]);
        progressBody.GetProperty("@odata.type").GetString().Should()
            .Be("#microsoft.graph.learningAssignment");
        progressBody.GetProperty("status").GetString().Should().Be("inProgress");
        progressBody.TryGetProperty("completedDateTime", out _).Should().BeFalse();

        var completionBody = ReadBody(handler.Requests[4]);
        completionBody.GetProperty("status").GetString().Should().Be("completed");
        completionBody.GetProperty("completionPercentage").GetInt32().Should().Be(100);
        completionBody.GetProperty("completedDateTime").GetDateTimeOffset().Should()
            .Be(ObservedAt.AddMinutes(5));
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(101)]
    public void Progress_adapter_rejects_invalid_percentages(int percentage)
    {
        var act = () => CertigoVivaLearningAdapter.ToAssignmentProgress(percentage, ObservedAt);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    private static JsonElement ReadBody(CapturedGraphRequest request)
    {
        request.Body.Should().NotBeNull();
        using var document = JsonDocument.Parse(request.Body!);
        return document.RootElement.Clone();
    }

    private static string FixtureDirectory()
        => Path.Combine(AppContext.BaseDirectory, "VivaLearningFixtures");
}
