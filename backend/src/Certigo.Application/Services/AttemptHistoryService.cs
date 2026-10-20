using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

public interface IAttemptHistoryService
{
    Task<AttemptHistoryPageDto> GetPageAsync(
        int limit,
        string? cursor,
        CancellationToken cancellationToken = default);
}

public sealed class AttemptHistoryService(
    IUserContext userContext,
    IAttemptRepository attempts,
    IEconomyOperationRepository economyOperations) : IAttemptHistoryService
{
    public const int DefaultLimit = 20;
    public const int MaximumLimit = 50;
    public const int ScanBudget = 200;
    private const int MaximumCursorBytes = 1_024;
    private const string QuizAttemptPrefix = "attempt::";
    private static readonly string[] RequiredQuizSteps =
        ["profile", "attempt", "progress", "learnerModel", "leaderboard", "events"];
    private static readonly JsonSerializerOptions CursorJsonOptions =
        new(JsonSerializerDefaults.Web);

    public async Task<AttemptHistoryPageDto> GetPageAsync(
        int limit,
        string? cursor,
        CancellationToken cancellationToken = default)
    {
        if (limit is < 1 or > MaximumLimit)
        {
            throw new RequestValidationException(
                $"History limit must be between 1 and {MaximumLimit}.");
        }

        var userId = userContext.UserId;
        var position = DecodeCursor(cursor, userId);
        var window = await attempts.ListHistoryWindowAsync(
            userId,
            position,
            ScanBudget,
            cancellationToken);
        var ordered = window.Records
            .Where(record => record.UserId == userId
                && record.Id.StartsWith(QuizAttemptPrefix, StringComparison.Ordinal))
            .OrderByDescending(record => record.SubmittedAt)
            .ThenByDescending(record => record.Id, StringComparer.Ordinal)
            .ToArray();

        var items = new List<AttemptHistorySummaryDto>(limit);
        AttemptRecord? lastScanned = null;
        var exhaustedAt = false;
        foreach (var record in ordered)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var operationId = EconomyOperationRecord.IdFor("quiz", record.ClientAttemptId);
            var operation = await economyOperations.GetAsync(userId, operationId, cancellationToken);
            if (operation is not null && !IsFullyCompleted(operation))
            {
                lastScanned = record;
                continue;
            }

            items.Add(new AttemptHistorySummaryDto(
                "quiz",
                record.Result.AttemptId,
                record.ClientAttemptId,
                record.TrackId,
                record.LessonId,
                record.SubmittedAt,
                record.Result.ScorePct,
                record.Result.Results.Count,
                record.Result.Results.Count(result => result.Correct),
                record.Result.Rewards.XpEarned,
                record.Result.Rewards.GemsEarned,
                record.PublicManifestId));
            lastScanned = record;
            if (items.Count == limit)
            {
                exhaustedAt = true;
                break;
            }
        }

        string? nextCursor = null;
        if (lastScanned is not null
            && (window.HasMore || (exhaustedAt && ordered[^1] != lastScanned)))
        {
            nextCursor = EncodeCursor(lastScanned, userId);
        }

        return new AttemptHistoryPageDto(items, nextCursor);
    }

    private static bool IsFullyCompleted(EconomyOperationRecord operation) =>
        operation.Status == EconomyOperationRecord.CompletedStatus
        && RequiredQuizSteps.All(operation.HasCompleted);

    private static string EncodeCursor(AttemptRecord record, string userId)
    {
        var cursor = new Cursor(
            1,
            OwnerDigest(userId),
            record.SubmittedAt,
            record.Id);
        var bytes = JsonSerializer.SerializeToUtf8Bytes(cursor, CursorJsonOptions);
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static AttemptHistoryPosition? DecodeCursor(string? encoded, string userId)
    {
        if (encoded is null) return null;
        if (encoded.Length is 0 or > 2_048)
        {
            throw new RequestValidationException("History cursor is invalid.");
        }

        try
        {
            var base64 = encoded.Replace('-', '+').Replace('_', '/');
            base64 = base64.PadRight(base64.Length + ((4 - base64.Length % 4) % 4), '=');
            var bytes = Convert.FromBase64String(base64);
            if (bytes.Length > MaximumCursorBytes) throw new FormatException();

            using var document = JsonDocument.Parse(bytes);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object
                || root.EnumerateObject().Count() != 4
                || !root.TryGetProperty("version", out var version)
                || version.GetInt32() != 1
                || !root.TryGetProperty("ownerDigest", out var digest)
                || digest.GetString() is not { } suppliedDigest
                || !CryptographicOperations.FixedTimeEquals(
                    Convert.FromHexString(suppliedDigest),
                    Convert.FromHexString(OwnerDigest(userId)))
                || !root.TryGetProperty("submittedAt", out var timestamp)
                || !timestamp.TryGetDateTimeOffset(out var submittedAt)
                || !root.TryGetProperty("id", out var idElement)
                || idElement.GetString() is not { } id
                || !id.StartsWith(QuizAttemptPrefix, StringComparison.Ordinal)
                || id.Length > 256)
            {
                throw new FormatException();
            }

            return new AttemptHistoryPosition(submittedAt, id);
        }
        catch (Exception exception) when (
            exception is FormatException
                or JsonException
                or InvalidOperationException
                or ArgumentException
                or OverflowException)
        {
            throw new RequestValidationException("History cursor is invalid.");
        }
    }

    private static string OwnerDigest(string userId) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(userId))).ToLowerInvariant();

    private sealed record Cursor(
        int Version,
        string OwnerDigest,
        DateTimeOffset SubmittedAt,
        string Id);
}
