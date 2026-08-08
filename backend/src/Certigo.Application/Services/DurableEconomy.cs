using System.Text.Json;
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
        if (operation.HasCompleted(step))
        {
            return operation;
        }

        await action();
        return await repository.MarkStepCompletedAsync(
            operation.UserId,
            operation.Id,
            step,
            cancellationToken);
    }

    public static Task<UserProfileDto> ApplyProfileOnceAsync(
        IUserRepository users,
        string userId,
        string displayName,
        string operationId,
        Func<UserProfileDto, UserProfileDto> apply,
        CancellationToken cancellationToken) =>
        OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var profile = await users.GetAsync(userId, cancellationToken)
                ?? ProfileDefaults.New(userId, displayName);
            if (profile.AppliedEconomyOperations?.Contains(operationId, StringComparer.Ordinal) == true)
            {
                return profile;
            }

            var markers = profile.AppliedEconomyOperations is null
                ? new List<string>()
                : new List<string>(profile.AppliedEconomyOperations);
            markers.Add(operationId);
            return await users.UpsertAsync(
                apply(profile) with { AppliedEconomyOperations = markers },
                cancellationToken);
        }, cancellationToken: cancellationToken);

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
