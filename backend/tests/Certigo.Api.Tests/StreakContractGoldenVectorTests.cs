using System.Net;
using System.Text;
using Certigo.Api.Functions;
using Certigo.Application.Dtos;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// Pins the wire format of the streak routes to golden vectors that are also read by
/// <c>packages/data/test/streak_contract_golden_test.dart</c>, where the real mobile
/// parser verifies them.
///
/// One committed artefact, two languages: this side fails if the API stops emitting the
/// bytes — through the real <see cref="StreakFunctions"/> and its real serializer — and
/// the Dart side fails if the client stops understanding them. The refusal vector matters
/// most: the client can only tell a business ruling from a malformed-request 400 by the
/// typed body this test proves the route sends.
/// </summary>
public sealed class StreakContractGoldenVectorTests
{
    [Fact]
    public async Task Status_route_emits_the_repairable_golden_bytes()
    {
        var body = await StatusBodyAsync(new StreakStatusDto(
            StreakDays: 12,
            LastActiveDate: new DateOnly(2025, 1, 3),
            FreezeTokens: 0,
            Repairable: true,
            RepairCostGems: 50,
            Reason: null,
            Gems: 120,
            RepairExpiresAt: new DateTimeOffset(2025, 1, 12, 0, 0, 0, TimeSpan.Zero),
            CoveredByFreeze: false));

        body.Should().Be(ReadGolden("status-repairable.golden.json"));
    }

    [Fact]
    public async Task Status_route_emits_the_intact_golden_bytes()
    {
        var body = await StatusBodyAsync(new StreakStatusDto(
            StreakDays: 12,
            LastActiveDate: new DateOnly(2025, 1, 5),
            FreezeTokens: 1,
            Repairable: false,
            RepairCostGems: 50,
            Reason: "intact",
            Gems: 120,
            RepairExpiresAt: null,
            CoveredByFreeze: false));

        body.Should().Be(
            ReadGolden("status-intact.golden.json"),
            "an absent window is emitted as null, which the client reads as 'no deadline'");
    }

    [Fact]
    public async Task Granted_repair_is_a_200_carrying_the_golden_bytes()
    {
        var (status, body) = await RepairReplyAsync(new StreakRepairResultDto(
            Success: true,
            StreakDays: 12,
            GemsSpent: 50,
            GemsBalance: 70,
            LastActiveDate: new DateOnly(2025, 1, 5),
            Error: null));

        status.Should().Be(HttpStatusCode.OK);
        body.Should().Be(ReadGolden("repair-granted.golden.json"));
    }

    [Fact]
    public async Task Refused_repair_is_a_400_carrying_the_golden_ruling_bytes()
    {
        var (status, body) = await RepairReplyAsync(new StreakRepairResultDto(
            Success: false,
            StreakDays: 12,
            GemsSpent: 0,
            GemsBalance: 30,
            LastActiveDate: new DateOnly(2025, 1, 3),
            Error: "insufficientGems"));

        status.Should().Be(HttpStatusCode.BadRequest);
        body.Should().Be(
            ReadGolden("repair-refused.golden.json"),
            "the refusal travels as a typed body under 400; a client that dropped it would "
            + "show a transport error where the server gave the exact reason");
    }

    private static async Task<string> StatusBodyAsync(StreakStatusDto status)
    {
        var function = new StreakFunctions(new FakeStreakRepairService { StatusResult = status });
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/streak");

        var response = await function.GetStreakStatus(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        return await response.ReadBodyAsStringAsync();
    }

    private static async Task<(HttpStatusCode Status, string Body)> RepairReplyAsync(StreakRepairResultDto result)
    {
        var function = new StreakFunctions(new FakeStreakRepairService { RepairResult = result });
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/streak/repair",
            new StreakRepairRequest("client-repair-1"));

        var response = await function.RepairStreak(request, context);

        return (response.StatusCode, await response.ReadBodyAsStringAsync());
    }

    private static string ReadGolden(string name)
        => File.ReadAllText(GoldenPath(name), new UTF8Encoding(false));

    private static string GoldenPath(string name)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(
                directory.FullName,
                "docs",
                "contracts",
                "learner-streak",
                "v1",
                name);
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException($"{name} was not found under docs/contracts/learner-streak/v1.");
    }
}
