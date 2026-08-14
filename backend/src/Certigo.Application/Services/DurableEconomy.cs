using System.Text.Json;
using System.Text;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Progress;

namespace Certigo.Application.Services;

internal sealed class EconomyOperationRejectedException(string failureCode) : Exception(failureCode)
{
    public string FailureCode { get; } = failureCode;
}

internal static class DurableEconomy
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    internal const int MaxProfileReceipts = 128;
    internal const int MaxProfileReceiptBytes = 256 * 1024;

    public static Task<EconomyOperationRecord> StartAsync<TPayload>(
        IEconomyOperationRepository repository,
        string userId,
        string kind,
        string operationKey,
        TPayload payload,
        IReadOnlyList<string> requiredSteps,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var id = EconomyOperationRecord.IdFor(kind, operationKey);
        return repository.GetOrCreateAsync(
            new EconomyOperationRecord(
                id,
                userId,
                kind,
                operationKey,
                JsonSerializer.Serialize(payload, JsonOptions),
                requiredSteps,
                Array.Empty<string>(),
                EconomyOperationRecord.PendingStatus,
                now,
                now),
            cancellationToken);
    }

    public static TPayload ReadPayload<TPayload>(EconomyOperationRecord operation) =>
        JsonSerializer.Deserialize<TPayload>(operation.PayloadJson, JsonOptions)
        ?? throw new InvalidOperationException($"Economy operation '{operation.Id}' has an invalid payload.");

    public static async Task<EconomyOperationRecord> RunStepAsync(
        IEconomyOperationRepository repository,
        EconomyOperationRecord operation,
        string step,
        Func<Task> action,
        CancellationToken cancellationToken)
    {
        var current = await repository.GetAsync(
            operation.UserId,
            operation.Id,
            cancellationToken) ?? operation;
        if (current.Status == EconomyOperationRecord.FailedStatus)
        {
            throw new ConcurrencyConflictException(
                $"Economy operation '{current.Id}' failed while step '{step}' was running.");
        }

        if (current.Status == EconomyOperationRecord.CompletedStatus
            || current.HasCompleted(step))
        {
            return current;
        }

        await action();
        return await repository.MarkStepCompletedAsync(
            current.UserId,
            current.Id,
            step,
            cancellationToken);
    }

    public static async Task<UserProfileDto> ApplyProfileOnceAsync(
        IEconomyOperationRepository operations,
        IUserRepository users,
        string userId,
        string displayName,
        EconomyOperationRecord operation,
        Func<UserProfileDto, UserProfileDto> apply,
        CancellationToken cancellationToken)
    {
        var application = await ApplyProfileOutcomeOnceAsync(
            operations,
            users,
            userId,
            displayName,
            operation,
            profile => (apply(profile), true),
            static outcome => outcome,
            static receipt => receipt,
            true,
            cancellationToken);
        return application.Profile;
    }

    public static async Task<ProfileOutcome<TOutcome>> ApplyProfileOutcomeStepAsync<TOutcome>(
        IEconomyOperationRepository operations,
        IUserRepository users,
        string userId,
        string displayName,
        EconomyOperationRecord operation,
        Func<UserProfileDto, (UserProfileDto Profile, TOutcome Outcome)> apply,
        TOutcome legacyOutcome,
        CancellationToken cancellationToken) =>
        await ApplyProfileOutcomeStepAsync<TOutcome, TOutcome>(
            operations,
            users,
            userId,
            displayName,
            operation,
            apply,
            static outcome => outcome,
            static receipt => receipt,
            legacyOutcome,
            cancellationToken);

    public static async Task<ProfileOutcome<TOutcome>> ApplyProfileOutcomeStepAsync<TOutcome, TReceipt>(
        IEconomyOperationRepository operations,
        IUserRepository users,
        string userId,
        string displayName,
        EconomyOperationRecord operation,
        Func<UserProfileDto, (UserProfileDto Profile, TOutcome Outcome)> apply,
        Func<TOutcome, TReceipt> toReceipt,
        Func<TReceipt, TOutcome> fromReceipt,
        TOutcome legacyOutcome,
        CancellationToken cancellationToken)
    {
        operation = await operations.GetAsync(userId, operation.Id, cancellationToken)
            ?? operation;
        if (operation.Status == EconomyOperationRecord.FailedStatus)
        {
            throw new ConcurrencyConflictException(
                $"Economy operation '{operation.Id}' failed before its profile outcome was committed.");
        }

        if (operation.HasCompleted("profile"))
        {
            var outcome = string.IsNullOrWhiteSpace(operation.OutcomeJson)
                ? legacyOutcome
                : ReadOutcome<TOutcome>(operation);
            if (string.IsNullOrWhiteSpace(operation.OutcomeJson))
            {
                operation = await operations.SetOutcomeAsync(
                    userId,
                    operation.Id,
                    JsonSerializer.Serialize(outcome, JsonOptions),
                    cancellationToken);
            }

            var profile = await MigrateLegacyMarkerAsync(
                operations,
                users,
                userId,
                displayName,
                operation,
                toReceipt(outcome),
                cancellationToken);
            return new ProfileOutcome<TOutcome>(
                operation,
                profile,
                outcome);
        }

        var application = await ApplyProfileOutcomeOnceAsync(
            operations,
            users,
            userId,
            displayName,
            operation,
            apply,
            toReceipt,
            fromReceipt,
            legacyOutcome,
            cancellationToken);
        var outcomeJson = JsonSerializer.Serialize(application.Outcome, JsonOptions);
        operation = await operations.SetOutcomeAsync(
            userId,
            operation.Id,
            outcomeJson,
            cancellationToken);
        operation = await operations.MarkStepCompletedAsync(
            userId,
            operation.Id,
            "profile",
            cancellationToken);
        return application with { Operation = operation };
    }

    private static Task<UserProfileDto> MigrateLegacyMarkerAsync<TReceipt>(
        IEconomyOperationRepository operations,
        IUserRepository users,
        string userId,
        string displayName,
        EconomyOperationRecord operation,
        TReceipt receiptOutcome,
        CancellationToken cancellationToken) =>
        OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var profile = await users.GetAsync(userId, cancellationToken)
                ?? ProfileDefaults.New(userId, displayName);
            if (profile.AppliedEconomyOperations?.Contains(
                    operation.Id,
                    StringComparer.Ordinal) != true)
            {
                return profile;
            }

            var receipts = profile.EconomyReceipts is null
                ? new List<EconomyProfileReceipt>()
                : new List<EconomyProfileReceipt>(profile.EconomyReceipts);
            if (receipts.All(receipt => !string.Equals(
                    receipt.OperationId,
                    operation.Id,
                    StringComparison.Ordinal)))
            {
                var receiptJson = JsonSerializer.Serialize(receiptOutcome, JsonOptions);
                receipts = await CompactReceiptsAsync(
                    operations,
                    userId,
                    receipts,
                    operation.Id,
                    receiptJson,
                    cancellationToken);
                receipts.Add(new EconomyProfileReceipt(
                    operation.Id,
                    operation.CreatedAt,
                    receiptJson));
            }

            var remaining = profile.AppliedEconomyOperations
                .Where(marker => !string.Equals(
                    marker,
                    operation.Id,
                    StringComparison.Ordinal))
                .ToList();
            return await users.UpsertAsync(
                profile with
                {
                    EconomyReceipts = receipts,
                    AppliedEconomyOperations = remaining.Count == 0 ? null : remaining,
                },
                cancellationToken);
        }, cancellationToken: cancellationToken);

    private static async Task<ProfileOutcome<TOutcome>> ApplyProfileOutcomeOnceAsync<TOutcome, TReceipt>(
        IEconomyOperationRepository operations,
        IUserRepository users,
        string userId,
        string displayName,
        EconomyOperationRecord operation,
        Func<UserProfileDto, (UserProfileDto Profile, TOutcome Outcome)> apply,
        Func<TOutcome, TReceipt> toReceipt,
        Func<TReceipt, TOutcome> fromReceipt,
        TOutcome legacyOutcome,
        CancellationToken cancellationToken) =>
        await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var profile = await users.GetAsync(userId, cancellationToken)
                ?? ProfileDefaults.New(userId, displayName);
            var receipts = profile.EconomyReceipts is null
                ? new List<EconomyProfileReceipt>()
                : new List<EconomyProfileReceipt>(profile.EconomyReceipts);
            var existing = receipts.FirstOrDefault(
                receipt => string.Equals(
                    receipt.OperationId,
                    operation.Id,
                    StringComparison.Ordinal));
            if (existing is not null)
            {
                var existingReceipt = JsonSerializer.Deserialize<TReceipt>(
                    existing.OutcomeJson,
                    JsonOptions)
                    ?? throw new InvalidOperationException(
                        $"Profile receipt '{operation.Id}' has an invalid outcome.");
                return new ProfileOutcome<TOutcome>(
                    operation,
                    profile,
                    fromReceipt(existingReceipt));
            }

            if (profile.AppliedEconomyOperations?.Contains(
                    operation.Id,
                    StringComparer.Ordinal) == true)
            {
                var receiptJson = JsonSerializer.Serialize(
                    toReceipt(legacyOutcome),
                    JsonOptions);
                receipts = await CompactReceiptsAsync(
                    operations,
                    userId,
                    receipts,
                    operation.Id,
                    receiptJson,
                    cancellationToken);
                receipts.Add(new EconomyProfileReceipt(
                    operation.Id,
                    operation.CreatedAt,
                    receiptJson));
                var remainingLegacyMarkers = profile.AppliedEconomyOperations
                    .Where(marker => !string.Equals(
                        marker,
                        operation.Id,
                        StringComparison.Ordinal))
                    .ToList();
                var migrated = await users.UpsertAsync(
                    profile with
                    {
                        EconomyReceipts = receipts,
                        AppliedEconomyOperations = remainingLegacyMarkers.Count == 0
                            ? null
                            : remainingLegacyMarkers,
                    },
                    cancellationToken);
                return new ProfileOutcome<TOutcome>(
                    operation,
                    migrated,
                    legacyOutcome);
            }

            var (updatedProfile, outcome) = apply(profile);
            var outcomeReceiptJson = JsonSerializer.Serialize(toReceipt(outcome), JsonOptions);
            receipts = await CompactReceiptsAsync(
                operations,
                userId,
                receipts,
                operation.Id,
                outcomeReceiptJson,
                cancellationToken);
            receipts.Add(new EconomyProfileReceipt(
                operation.Id,
                operation.CreatedAt,
                outcomeReceiptJson));
            var stored = await users.UpsertAsync(
                updatedProfile with { EconomyReceipts = receipts },
                cancellationToken);
            return new ProfileOutcome<TOutcome>(operation, stored, outcome);
        }, cancellationToken: cancellationToken);

    private static TOutcome ReadOutcome<TOutcome>(EconomyOperationRecord operation)
    {
        if (string.IsNullOrWhiteSpace(operation.OutcomeJson))
        {
            throw new InvalidOperationException(
                $"Economy operation '{operation.Id}' completed its profile step without an outcome.");
        }

        return JsonSerializer.Deserialize<TOutcome>(operation.OutcomeJson, JsonOptions)
            ?? throw new InvalidOperationException(
                $"Economy operation '{operation.Id}' has an invalid outcome.");
    }

    private static async Task<List<EconomyProfileReceipt>> CompactReceiptsAsync(
        IEconomyOperationRepository operations,
        string userId,
        List<EconomyProfileReceipt> receipts,
        string incomingOperationId,
        string incomingOutcomeJson,
        CancellationToken cancellationToken)
    {
        var incomingBytes = Encoding.UTF8.GetByteCount(incomingOperationId)
            + Encoding.UTF8.GetByteCount(incomingOutcomeJson)
            + 32;
        if (receipts.Count < MaxProfileReceipts
            && ReceiptBytes(receipts) + incomingBytes <= MaxProfileReceiptBytes)
        {
            return receipts;
        }

        var compacted = new List<EconomyProfileReceipt>(receipts);
        foreach (var receipt in receipts.OrderBy(candidate => candidate.AppliedAt))
        {
            var journal = await operations.GetAsync(
                userId,
                receipt.OperationId,
                cancellationToken);
            if (journal?.Status is EconomyOperationRecord.CompletedStatus
                or EconomyOperationRecord.FailedStatus)
            {
                compacted.Remove(receipt);
            }

            if (compacted.Count < MaxProfileReceipts
                && ReceiptBytes(compacted) + incomingBytes <= MaxProfileReceiptBytes)
            {
                return compacted;
            }
        }

        throw new InvalidOperationException(
            $"User '{userId}' has too many pending economy receipts; reconciliation is required.");
    }

    private static int ReceiptBytes(IEnumerable<EconomyProfileReceipt> receipts) =>
        receipts.Sum(receipt =>
            Encoding.UTF8.GetByteCount(receipt.OperationId)
            + Encoding.UTF8.GetByteCount(receipt.OutcomeJson)
            + 32);

    public static string EventId(string operationId, string eventType) =>
        $"{operationId}::event::{eventType}";

    public static async Task UpsertMasteriesWithoutRegressionAsync(
        IProgressRepository progress,
        string userId,
        IReadOnlyList<ConceptMastery> candidates,
        CancellationToken cancellationToken)
    {
        var applicable = new List<ConceptMastery>();
        foreach (var candidate in candidates)
        {
            var current = await progress.GetMasteryAsync(
                userId,
                candidate.TrackId,
                candidate.ConceptId,
                cancellationToken);
            if (current is null
                || candidate.LastReviewedAt > current.LastReviewedAt
                || candidate.LastReviewedAt == current.LastReviewedAt && candidate.Reps > current.Reps)
            {
                applicable.Add(candidate);
            }

        }

        await progress.UpsertMasteryBatchAsync(userId, applicable, cancellationToken);
    }

    public static async Task UpsertLearnerModelWithoutRegressionAsync(
        ILearnerModelRepository learnerModels,
        LearnerModelRecord candidate,
        CancellationToken cancellationToken)
    {
        var current = await learnerModels.GetAsync(
            candidate.UserId,
            candidate.TrackId,
            cancellationToken);
        var currentAttempts = current?.Concepts.Sum(concept => concept.Attempts) ?? -1;
        var candidateAttempts = candidate.Concepts.Sum(concept => concept.Attempts);
        if (current is not null
            && (current.UpdatedAt > candidate.UpdatedAt
                || current.UpdatedAt == candidate.UpdatedAt && currentAttempts >= candidateAttempts))
        {
            return;
        }

        await learnerModels.UpsertAsync(candidate, cancellationToken);
    }
}

internal sealed record ProfileOutcome<TOutcome>(
    EconomyOperationRecord Operation,
    UserProfileDto Profile,
    TOutcome Outcome);
