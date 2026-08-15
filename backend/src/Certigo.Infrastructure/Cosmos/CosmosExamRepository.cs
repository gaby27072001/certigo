using System.Net;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosExamRepository(CosmosContext context) : IExamRepository
{
    public async Task CreateAsync(ExamRecord exam, CancellationToken cancellationToken = default)
    {
        try
        {
            await context.Attempts.CreateItemAsync(
                exam,
                new PartitionKey(exam.UserId),
                cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
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
