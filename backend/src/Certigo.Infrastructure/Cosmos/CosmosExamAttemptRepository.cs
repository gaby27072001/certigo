using Microsoft.Azure.Cosmos;
using System.Net;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosExamAttemptRepository(CosmosContext context) : IExamAttemptRepository
{
    public async Task<ExamAttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default)
    {
        // Shares the attempts container with lesson attempts; the kind = 'exam'
        // filter keeps the two record shapes from colliding on idempotency lookups.
        var query = new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId AND c.clientAttemptId = @clientAttemptId AND c.kind = 'exam'")
            .WithParameter("@userId", userId)
            .WithParameter("@clientAttemptId", clientAttemptId);
        using var iterator = context.Attempts.GetItemQueryIterator<ExamAttemptRecord>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(userId),
            MaxItemCount = 1
        });

        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            return page.FirstOrDefault();
        }

        return null;
    }

    public async Task<ExamAttemptRecord?> GetByExamIdAsync(
        string userId,
        string examId,
        CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.userId = @userId AND c.examId = @examId AND c.kind = 'exam'")
            .WithParameter("@userId", userId)
            .WithParameter("@examId", examId);
        using var iterator = context.Attempts.GetItemQueryIterator<ExamAttemptRecord>(
            query,
            requestOptions: new QueryRequestOptions
            {
                PartitionKey = new PartitionKey(userId),
                MaxItemCount = 1
            });

        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            return page.FirstOrDefault();
        }

        return null;
    }

    public async Task CreateAsync(ExamAttemptRecord attempt, CancellationToken cancellationToken = default)
    {
        try
        {
            await context.Attempts.CreateItemAsync(attempt, new PartitionKey(attempt.UserId), cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            throw new DuplicateRecordException($"Exam attempt '{attempt.Id}' already exists.");
        }
    }
}
