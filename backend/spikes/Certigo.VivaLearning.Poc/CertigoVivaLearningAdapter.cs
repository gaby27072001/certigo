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
        ValidatePublicLinkIdentifier(lesson.TrackId, nameof(lesson.TrackId));
        ValidatePublicLinkIdentifier(lesson.LessonId, nameof(lesson.LessonId));
        if (lesson.EstimatedMinutes <= 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(lesson),
                "EstimatedMinutes must be positive.");
        }

        var deepLink = new Uri(
            _certigoPublicBaseUri,
            $"learn/{Uri.EscapeDataString(lesson.TrackId)}/{Uri.EscapeDataString(lesson.LessonId)}");

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
        if (!baseUri.IsAbsoluteUri
            || baseUri.Scheme != Uri.UriSchemeHttps
            || !baseUri.Host.EndsWith(".invalid", StringComparison.OrdinalIgnoreCase)
            || !string.IsNullOrEmpty(baseUri.UserInfo)
            || !baseUri.IsDefaultPort
            || baseUri.AbsolutePath != "/"
            || !string.IsNullOrEmpty(baseUri.Query)
            || !string.IsNullOrEmpty(baseUri.Fragment))
        {
            throw new ArgumentException(
                "The offline POC only accepts an absolute HTTPS origin under .invalid.",
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

    private static void ValidatePublicLinkIdentifier(string value, string parameterName)
    {
        if (value.Length is < 1 or > 128
            || !IsAsciiLetterOrDigit(value[0])
            || value.Any(character =>
                !IsAsciiLetterOrDigit(character) && character is not '.' and not '_' and not '-'))
        {
            throw new ArgumentException(
                "Public link identifiers must match [A-Za-z0-9][A-Za-z0-9._-]{0,127}.",
                parameterName);
        }
    }

    private static bool IsAsciiLetterOrDigit(char value)
        => value is >= 'A' and <= 'Z'
            or >= 'a' and <= 'z'
            or >= '0' and <= '9';
}
