using System.Text.Json;
using System.Text.Json.Serialization;

namespace Certigo.VivaLearning.Poc;

public enum VivaLearningAuthMode
{
    DelegatedAdministrator,
    DelegatedUser,
    Application
}

public sealed record VivaLearningOperationContract(
    string Operation,
    string Method,
    string Path,
    VivaLearningAuthMode AuthMode,
    string Permission,
    string Preconditions)
{
    public static IReadOnlyList<VivaLearningOperationContract> All { get; } =
    [
        new(
            "Register provider",
            "POST",
            "/employeeExperience/learningProviders",
            VivaLearningAuthMode.DelegatedAdministrator,
            "LearningProvider.ReadWrite",
            "Knowledge Administrator plus Viva Learning or Viva Suite license"),
        new(
            "Publish content",
            "PATCH",
            "/employeeExperience/learningProviders/{providerId}/learningContents(externalId='{externalId}')",
            VivaLearningAuthMode.Application,
            "LearningContent.ReadWrite.All",
            "Administrator consent; delegated access is not supported by this endpoint"),
        new(
            "Read my assignments",
            "GET",
            "/me/employeeExperience/learningCourseActivities",
            VivaLearningAuthMode.DelegatedUser,
            "LearningAssignedCourse.Read.All",
            "Signed-in work or school user; application access is not supported by this endpoint"),
        new(
            "Sync assignment progress",
            "PATCH",
            "/employeeExperience/learningProviders/{providerId}/learningCourseActivities/{activityId}",
            VivaLearningAuthMode.Application,
            "LearningAssignedCourse.ReadWrite.All",
            "Provider registered with isCourseActivitySyncEnabled=true")
    ];
}

public sealed record VivaLearningPocOptions(bool Enabled, Uri GraphBaseUri);

public sealed class LearningProviderWriteDto
{
    public required string DisplayName { get; init; }
    public required string SquareLogoWebUrlForDarkTheme { get; init; }
    public required string LongLogoWebUrlForDarkTheme { get; init; }
    public required string SquareLogoWebUrlForLightTheme { get; init; }
    public required string LongLogoWebUrlForLightTheme { get; init; }
    public string? LoginWebUrl { get; init; }
    public bool IsCourseActivitySyncEnabled { get; init; }
}

public sealed class LearningProviderDto
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }
    public bool IsCourseActivitySyncEnabled { get; init; }
}

public sealed class LearningContentWriteDto
{
    public required string Title { get; init; }
    public required string Description { get; init; }
    public required string ContentWebUrl { get; init; }
    public required string ExternalId { get; init; }
    public required string LanguageTag { get; init; }
    public required string Duration { get; init; }
    public required string Format { get; init; }
    public required string Level { get; init; }
    public required string SourceName { get; init; }
    public bool IsActive { get; init; } = true;
    public bool IsPremium { get; init; }
    public bool IsSearchable { get; init; } = true;
    public DateTimeOffset? LastModifiedDateTime { get; init; }
    public IReadOnlyList<string> AdditionalTags { get; init; } = [];
    public IReadOnlyList<string> SkillTags { get; init; } = [];
}

public sealed class LearningContentDto
{
    public required string Id { get; init; }
    public required string ExternalId { get; init; }
    public required string Title { get; init; }
    public required string ContentWebUrl { get; init; }
}

public sealed class LearningCourseActivityDto
{
    [JsonPropertyName("@odata.type")]
    public string? ODataType { get; init; }

    public required string Id { get; init; }
    public string? ExternalCourseActivityId { get; init; }
    public required string LearningContentId { get; init; }
    public required string LearningProviderId { get; init; }
    [JsonPropertyName("learnerUserId")]
    public required string EnterpriseLearnerObjectId { get; init; }
    public required string Status { get; init; }
    public int? CompletionPercentage { get; init; }
    public DateTimeOffset? CompletedDateTime { get; init; }
}

public sealed class LearningCourseActivityUpdateDto
{
    [JsonPropertyName("@odata.type")]
    public string ODataType { get; init; } = "#microsoft.graph.learningAssignment";

    public required string Status { get; init; }
    public int CompletionPercentage { get; init; }
    public DateTimeOffset? CompletedDateTime { get; init; }
}

public sealed class GraphCollectionResponse<T>
{
    [JsonPropertyName("@odata.nextLink")]
    public string? NextLink { get; init; }

    public IReadOnlyList<T> Value { get; init; } = [];
}

public sealed record CertigoLessonDescriptor(
    string TrackId,
    string LessonId,
    string Title,
    string Summary,
    int EstimatedMinutes,
    string LanguageTag,
    string TrackLevel,
    DateTimeOffset LastModifiedDateTime);

public sealed record PublishedCertigoContent(
    string ProviderId,
    string GraphContentId,
    string ExternalId,
    Uri ContentWebUrl);

public sealed record VivaLearningPocScenarioResult(
    LearningProviderDto Provider,
    LearningContentDto Content,
    LearningCourseActivityDto Assignment,
    Uri DeepLink,
    LearningCourseActivityUpdateDto InProgress,
    LearningCourseActivityUpdateDto Completed);

public sealed record CapturedGraphRequest(
    string Method,
    string PathAndQuery,
    string? Body,
    IReadOnlyDictionary<string, IReadOnlyList<string>> Headers);

public sealed class VivaLearningGraphException(string message) : InvalidOperationException(message);

internal static class VivaLearningJson
{
    public static JsonSerializerOptions Options { get; } = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        PropertyNameCaseInsensitive = true
    };
}
