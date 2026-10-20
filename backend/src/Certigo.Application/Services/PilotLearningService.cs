using System.Text.RegularExpressions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

public interface IPilotLearningService
{
    Task<PilotContentPackage?> GetContentAsync(
        string pilotId,
        CancellationToken cancellationToken = default);

    Task<PilotHistoryDto?> GetHistoryAsync(
        string pilotId,
        string contentDigest,
        CancellationToken cancellationToken = default);

    Task<PilotLessonProgressDto?> RecordAccessAsync(
        string pilotId,
        string lessonId,
        string contentDigest,
        bool markRead,
        CancellationToken cancellationToken = default);
}

public sealed class PilotLearningService(
    IUserContext userContext,
    IClock clock,
    IPilotContentCatalog content,
    IPilotHistoryRepository history) : IPilotLearningService
{
    private static readonly Regex DigestPattern = new(
        "^sha256:[0-9a-f]{64}$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);

    public Task<PilotContentPackage?> GetContentAsync(
        string pilotId,
        CancellationToken cancellationToken = default) =>
        content.GetAsync(pilotId, cancellationToken);

    public async Task<PilotHistoryDto?> GetHistoryAsync(
        string pilotId,
        string contentDigest,
        CancellationToken cancellationToken = default)
    {
        var package = await CurrentPackageAsync(pilotId, contentDigest, cancellationToken);
        if (package is null)
        {
            return null;
        }

        var records = await history.ListAsync(
            userContext.UserId,
            package.PilotId,
            package.ContentDigest,
            cancellationToken);
        var lessons = records
            .OrderByDescending(record => record.LastAccessedAt)
            .ThenBy(record => record.LessonId, StringComparer.Ordinal)
            .Select(record => new PilotLessonProgressDto(
                record.LessonId,
                record.LastAccessedAt,
                record.MarkedReadAt))
            .ToArray();
        return new PilotHistoryDto(
            package.PilotId,
            package.ContentDigest,
            lessons.FirstOrDefault()?.LessonId,
            lessons);
    }

    public async Task<PilotLessonProgressDto?> RecordAccessAsync(
        string pilotId,
        string lessonId,
        string contentDigest,
        bool markRead,
        CancellationToken cancellationToken = default)
    {
        var package = await CurrentPackageAsync(pilotId, contentDigest, cancellationToken);
        if (package is null || !package.LessonIds.Contains(lessonId))
        {
            return null;
        }

        var now = clock.UtcNow;
        var saved = await history.RecordAsync(
            new PilotLessonHistoryRecord(
                CosmosHistoryId(package.PilotId, package.ContentDigest, lessonId),
                userContext.UserId,
                package.PilotId,
                package.ContentDigest,
                lessonId,
                now,
                markRead ? now : null),
            markRead,
            cancellationToken);
        return new PilotLessonProgressDto(
            saved.LessonId,
            saved.LastAccessedAt,
            saved.MarkedReadAt);
    }

    private async Task<PilotContentPackage?> CurrentPackageAsync(
        string pilotId,
        string contentDigest,
        CancellationToken cancellationToken)
    {
        if (!DigestPattern.IsMatch(contentDigest))
        {
            return null;
        }

        var package = await content.GetAsync(pilotId, cancellationToken);
        return package?.ContentDigest == contentDigest ? package : null;
    }

    internal static string CosmosHistoryId(
        string pilotId,
        string contentDigest,
        string lessonId) =>
        $"pilot-history::{pilotId}::{contentDigest}::{lessonId}";
}
