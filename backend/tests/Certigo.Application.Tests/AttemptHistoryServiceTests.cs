using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class AttemptHistoryServiceTests
{
    private const string OwnerId = "user-1";
    private static readonly string[] RequiredSteps =
        ["profile", "attempt", "progress", "learnerModel", "leaderboard", "events"];

    [Fact]
    public async Task GetPageAsync_IsolatesOwner_AndExcludesIncompleteDurableOperations()
    {
        var attempts = new InMemoryAttemptRepository();
        var operations = new InMemoryEconomyOperationRepository();
        attempts.Seed(Attempt(OwnerId, "completed", DateTimeOffset.UnixEpoch));
        attempts.Seed(Attempt(OwnerId, "pending", DateTimeOffset.UnixEpoch.AddMinutes(-1)));
        attempts.Seed(Attempt("user-2", "other-owner", DateTimeOffset.UnixEpoch.AddMinutes(1)));
        await SeedOperationAsync(operations, OwnerId, "completed", completed: true);
        await SeedOperationAsync(operations, OwnerId, "pending", completed: false);

        var service = new AttemptHistoryService(
            new FakeUserContext(OwnerId, "Learner"),
            attempts,
            operations);

        var page = await service.GetPageAsync(20, null);

        page.Items.Should().ContainSingle();
        page.Items[0].ClientAttemptId.Should().Be("completed");
        page.Items[0].XpEarned.Should().Be(25);
    }

    [Fact]
    public async Task GetPageAsync_OrdersTimestampThenId_AndContinuesAcrossTiedTimestamps()
    {
        var attempts = new InMemoryAttemptRepository();
        var operations = new InMemoryEconomyOperationRepository();
        var submittedAt = DateTimeOffset.UnixEpoch;
        foreach (var id in new[] { "a", "c", "b" })
        {
            attempts.Seed(Attempt(OwnerId, id, submittedAt));
            await SeedOperationAsync(operations, OwnerId, id, completed: true);
        }

        var service = new AttemptHistoryService(
            new FakeUserContext(OwnerId, "Learner"),
            attempts,
            operations);

        var first = await service.GetPageAsync(2, null);
        var second = await service.GetPageAsync(2, first.NextCursor);

        first.Items.Select(item => item.ClientAttemptId).Should().Equal("c", "b");
        first.NextCursor.Should().NotBeNullOrEmpty();
        second.Items.Select(item => item.ClientAttemptId).Should().Equal("a");
        second.NextCursor.Should().BeNull();
    }

    [Fact]
    public async Task GetPageAsync_RejectsInvalidLimitAndCursorBoundToAnotherOwner()
    {
        var attempts = new InMemoryAttemptRepository();
        var operations = new InMemoryEconomyOperationRepository();
        attempts.Seed(Attempt(OwnerId, "one", DateTimeOffset.UnixEpoch));
        attempts.Seed(Attempt(OwnerId, "two", DateTimeOffset.UnixEpoch.AddMinutes(-1)));
        await SeedOperationAsync(operations, OwnerId, "one", completed: true);
        await SeedOperationAsync(operations, OwnerId, "two", completed: true);
        var ownerService = new AttemptHistoryService(
            new FakeUserContext(OwnerId, "Learner"),
            attempts,
            operations);
        var cursor = (await ownerService.GetPageAsync(1, null)).NextCursor;

        var otherOwnerService = new AttemptHistoryService(
            new FakeUserContext("user-2", "Other"),
            attempts,
            operations);

        await FluentActions.Invoking(() => ownerService.GetPageAsync(51, null))
            .Should().ThrowAsync<RequestValidationException>();
        await FluentActions.Invoking(() => ownerService.GetPageAsync(0, null))
            .Should().ThrowAsync<RequestValidationException>();
        await FluentActions.Invoking(() => otherOwnerService.GetPageAsync(1, cursor))
            .Should().ThrowAsync<RequestValidationException>();
        await FluentActions.Invoking(() => ownerService.GetPageAsync(1, "not-a-cursor"))
            .Should().ThrowAsync<RequestValidationException>();
    }

    [Fact]
    public async Task GetPageAsync_AdvancesCursorAfterScanBudgetOfUnconfirmedAttempts()
    {
        var attempts = new InMemoryAttemptRepository();
        var operations = new InMemoryEconomyOperationRepository();
        for (var index = 0; index < AttemptHistoryService.ScanBudget; index++)
        {
            var clientAttemptId = $"pending-{index:D3}";
            var submittedAt = DateTimeOffset.UnixEpoch.AddMinutes(index);
            attempts.Seed(Attempt(OwnerId, clientAttemptId, submittedAt));
            await SeedOperationAsync(operations, OwnerId, clientAttemptId, completed: false);
        }

        attempts.Seed(Attempt(
            OwnerId,
            "confirmed-after-budget",
            DateTimeOffset.UnixEpoch.AddDays(-1)));
        await SeedOperationAsync(operations, OwnerId, "confirmed-after-budget", completed: true);
        var service = new AttemptHistoryService(
            new FakeUserContext(OwnerId, "Learner"),
            attempts,
            operations);

        var first = await service.GetPageAsync(20, null);
        var second = await service.GetPageAsync(20, first.NextCursor);

        first.Items.Should().BeEmpty();
        first.NextCursor.Should().NotBeNullOrEmpty();
        second.Items.Should().ContainSingle()
            .Which.ClientAttemptId.Should().Be("confirmed-after-budget");
        second.NextCursor.Should().BeNull();
    }

    private static AttemptRecord Attempt(
        string userId,
        string clientAttemptId,
        DateTimeOffset submittedAt) =>
        new(
            $"attempt::{clientAttemptId}",
            userId,
            clientAttemptId,
            "track-1",
            "lesson-1",
            submittedAt.AddMinutes(-1),
            submittedAt,
            new SubmitQuizResult(
                $"result-{clientAttemptId}",
                80,
                [
                    new ItemResultDto(
                        "question-1", true, "concept-1", ["private-answer"],
                        "private explanation", 0.25),
                ],
                new RewardsDto(25, 125, false, false, 0, []),
                ["private-weak-concept"],
                null));

    private static async Task SeedOperationAsync(
        InMemoryEconomyOperationRepository operations,
        string userId,
        string clientAttemptId,
        bool completed)
    {
        var operationId = EconomyOperationRecord.IdFor("quiz", clientAttemptId);
        await operations.GetOrCreateAsync(new EconomyOperationRecord(
            operationId,
            userId,
            "quiz",
            clientAttemptId,
            "{}",
            RequiredSteps,
            [],
            EconomyOperationRecord.PendingStatus,
            DateTimeOffset.UnixEpoch,
            DateTimeOffset.UnixEpoch));
        if (!completed) return;
        foreach (var step in RequiredSteps)
        {
            await operations.MarkStepCompletedAsync(userId, operationId, step);
        }
    }
}
