using System.Net;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosExamRepository(CosmosContext context) : IExamRepository
{
    public async Task CreateAsync(ExamRecord exam, CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            exam.UserId,
            cancellationToken);
        await writeLease.MarkMutationDispatchedAsync();
        try
        {
            var response = await context.Attempts.CreateItemAsync(
                exam,
                new PartitionKey(exam.UserId),
                cancellationToken: cancellationToken);
            await writeLease.CommitAsync(
                CosmosContainers.Attempts,
                response.Headers.Session,
                cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            writeLease.MarkDefinitelyNotCommitted();
            throw new DuplicateRecordException($"Exam '{exam.Id}' already exists.");
        }
    }

    public async Task<ExamRecord?> GetAsync(
        string userId,
        string examId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await context.Attempts.ReadItemAsync<ExamRecord>(
                $"exam::{examId}",
                new PartitionKey(userId),
                cancellationToken: cancellationToken);
            return string.Equals(response.Resource.Kind, "exam-issued", StringComparison.Ordinal)
                ? response.Resource
                : null;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }
    }
}
