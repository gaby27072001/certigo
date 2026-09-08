using System.Security.Cryptography;
using System.Text;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Organizations;

namespace Certigo.Application.Services;

public sealed class VivaLearningService(
    IOrganizationAuthorizationHandler authorization,
    IVivaLearningFixtureCatalog catalog,
    VivaLearningFeatureOptions options) : IVivaLearningService
{
    public async Task<VivaLearningProviderDto> GetProviderAsync(
        string organizationId,
        CancellationToken cancellationToken = default)
    {
        EnsureAvailable();
        await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ManageAssignments,
            cancellationToken: cancellationToken);
        return catalog.Provider;
    }

    public async Task<IReadOnlyList<VivaLearningContentDto>> GetLearningContentAsync(
        string organizationId,
        CancellationToken cancellationToken = default)
    {
        EnsureAvailable();
        await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ManageAssignments,
            cancellationToken: cancellationToken);
        return catalog.LearningContent
            .Select(item => VivaLearningOrganizationMapper.Map(
                organizationId,
                item,
                options.PublicWebOrigin))
            .ToArray();
    }

    private void EnsureAvailable()
    {
        if (options.Mode == VivaLearningFeatureMode.Off)
        {
            throw new VivaLearningFeatureDisabledException();
        }
    }
}

public static class VivaLearningOrganizationMapper
{
    public static VivaLearningContentDto Map(
        string organizationId,
        VivaLearningContentFixtureDto content,
        Uri publicWebOrigin)
    {
        EnsureIdentifier(organizationId, nameof(organizationId));
        EnsureIdentifier(content.TrackId, nameof(content.TrackId));
        EnsureIdentifier(content.LessonId, nameof(content.LessonId));
        var origin = VivaLearningFeatureOptions.ParseFixtureOrigin(publicWebOrigin.AbsoluteUri);
        var organizationScope = Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(
                    $"certigo-viva-organization:v1:{organizationId}")))
            .ToLowerInvariant()[..24];
        var externalId =
            $"certigo:{organizationScope}:{content.TrackId}:{content.LessonId}";
        var contentWebUrl = new Uri(
            origin,
            $"learn/{Uri.EscapeDataString(content.TrackId)}/{Uri.EscapeDataString(content.LessonId)}");

        return new VivaLearningContentDto(
            content.Id,
            organizationId,
            externalId,
            content.TrackId,
            content.LessonId,
            content.Title,
            content.Description,
            contentWebUrl.AbsoluteUri,
            content.LanguageTag,
            FormattableString.Invariant($"PT{content.EstimatedMinutes}M"),
            content.Format,
            content.Level,
            content.SourceName,
            content.IsActive,
            content.IsPremium,
            content.IsSearchable);
    }

    private static void EnsureIdentifier(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value)
            || value.Length > 128
            || !value.All(character =>
                char.IsAsciiLetterOrDigit(character) || character is '-' or '_'))
        {
            throw new ArgumentException(
                "Viva Learning mapping identifiers must contain only ASCII letters, digits, '-' or '_'.",
                parameterName);
        }
    }
}
