namespace Certigo.Application.Dtos;

public enum AccountDeletionStatus
{
    NotRequested,
    Pending,
    Completed,
}

public sealed record AccountDeletionDto(
    AccountDeletionStatus Status,
    int CompletedSteps,
    int TotalSteps,
    DateTimeOffset? RequestedAt = null,
    DateTimeOffset? CompletedAt = null,
    string? FailureCode = null,
    int? RetryAfterSeconds = null);
