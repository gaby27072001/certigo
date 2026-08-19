namespace Certigo.VivaLearning.Poc;

public sealed class CertigoVivaLearningAdapter(Uri certigoPublicBaseUri)
{
    private readonly Uri _certigoPublicBaseUri = ValidateBaseUri(certigoPublicBaseUri);

    public LearningContentWriteDto ToLearningContent(CertigoLessonDescriptor lesson)
    {
        ArgumentNullException.ThrowIfNull(lesson);
        ArgumentException.ThrowIfNullOrWhiteSpace(lesson.TrackId);
        ArgumentException.ThrowIfNullOrWhiteSpace(lesson.LessonId);
        ArgumentException.ThrowIfNullOrWhiteSpace(lesson.Title);
        if (lesson.EstimatedMinutes <= 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(lesson),
                "EstimatedMinutes must be positive.");
        }

        var deepLink = new Uri(
            _certigoPublicBaseUri,
            $"lesson/{Uri.EscapeDataString(lesson.TrackId)}/{Uri.EscapeDataString(lesson.LessonId)}");

        return new LearningContentWriteDto
        {
            ExternalId = $"certigo:{lesson.TrackId}:{lesson.LessonId}",
            Title = lesson.Title,
            Description = lesson.Summary,
            ContentWebUrl = deepLink.AbsoluteUri,
            LanguageTag = lesson.LanguageTag,
            Duration = $"PT{lesson.EstimatedMinutes}M",
            Format = "Course",
            Level = ToVivaLevel(lesson.TrackLevel),
            SourceName = "Certigo",
            LastModifiedDateTime = lesson.LastModifiedDateTime.ToUniversalTime(),
            AdditionalTags = [lesson.TrackId, lesson.LessonId],
            SkillTags = [lesson.TrackId],
            IsActive = true,
            IsPremium = true,
            IsSearchable = true
        };
    }

    public static PublishedCertigoContent ToPublishedMapping(
        string providerId,
        LearningContentDto content)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(providerId);
        ArgumentNullException.ThrowIfNull(content);
        if (!Uri.TryCreate(content.ContentWebUrl, UriKind.Absolute, out var contentWebUrl)
            || contentWebUrl.Scheme != Uri.UriSchemeHttps)
        {
            throw new InvalidOperationException("Published Certigo content must expose an HTTPS URL.");
        }

        return new PublishedCertigoContent(
            providerId,
            content.Id,
            content.ExternalId,
            contentWebUrl);
    }

    public static Uri ResolveAssignmentDeepLink(
        LearningCourseActivityDto assignment,
        PublishedCertigoContent published)
    {
        ArgumentNullException.ThrowIfNull(assignment);
        ArgumentNullException.ThrowIfNull(published);

        if (!string.Equals(
                assignment.LearningProviderId,
                published.ProviderId,
                StringComparison.Ordinal)
            || !string.Equals(
                assignment.LearningContentId,
                published.GraphContentId,
                StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "The Viva assignment does not reference the published Certigo content mapping.");
        }

        return published.ContentWebUrl;
    }

    public static LearningCourseActivityUpdateDto ToAssignmentProgress(
        int completionPercentage,
        DateTimeOffset observedAt)
    {
        if (completionPercentage is < 0 or > 100)
        {
            throw new ArgumentOutOfRangeException(
                nameof(completionPercentage),
                "Completion percentage must be between 0 and 100.");
        }

        return new LearningCourseActivityUpdateDto
        {
            Status = completionPercentage switch
            {
                0 => "notStarted",
                100 => "completed",
                _ => "inProgress"
            },
            CompletionPercentage = completionPercentage,
            CompletedDateTime = completionPercentage == 100
                ? observedAt.ToUniversalTime()
                : null
        };
    }

    private static Uri ValidateBaseUri(Uri baseUri)
    {
        ArgumentNullException.ThrowIfNull(baseUri);
        if (!baseUri.IsAbsoluteUri || baseUri.Scheme != Uri.UriSchemeHttps)
        {
            throw new ArgumentException(
                "The Certigo Viva Learning content URL must use absolute HTTPS.",
                nameof(baseUri));
        }

        var builder = new UriBuilder(baseUri)
        {
            Query = string.Empty,
            Fragment = string.Empty,
            Path = $"{baseUri.AbsolutePath.TrimEnd('/')}/"
        };
        return builder.Uri;
    }

    private static string ToVivaLevel(string trackLevel)
        => trackLevel.Trim().ToLowerInvariant() switch
        {
            "fundamentals" or "beginner" => "Beginner",
            "advanced" or "expert" => "Advanced",
            _ => "Intermediate"
        };
}
