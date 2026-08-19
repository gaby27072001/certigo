using System.Text.Json;
using System.Text.Json.Serialization;
using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class CosmosSerializationTests
{
    private static JsonSerializerOptions SerializerOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        return options;
    }

    [Fact]
    public void User_profile_round_trips_camel_case_etag_and_bounded_economy_receipts()
    {
        var profile = new UserProfileDto(
            "user-1",
            "Tester",
            "tester",
            null,
            100,
            2,
            3,
            1,
            50,
            20,
            40,
            "az-900",
            EconomyReceipts:
            [
                new EconomyProfileReceipt(
                    "operation::quiz::a1",
                    new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero),
                    "{\"attemptId\":\"result-1\"}"),
            ])
        {
            ETag = "\"etag-1\"",
        };

        var json = JsonSerializer.Serialize(profile, SerializerOptions());
        var restored = JsonSerializer.Deserialize<UserProfileDto>(json, SerializerOptions());

        json.Should().Contain("\"displayName\"");
        using var document = JsonDocument.Parse(json);
        document.RootElement.GetProperty("_etag").GetString().Should().Be("\"etag-1\"");
        json.Should().Contain("\"economyReceipts\"");
        document.RootElement.GetProperty("appliedEconomyOperations").ValueKind
            .Should().Be(JsonValueKind.Null);
        restored.Should().BeEquivalentTo(profile);
    }

    [Fact]
    public void Legacy_profile_markers_remain_readable_for_safe_receipt_migration()
    {
        const string legacyJson = """
            {
              "id": "user-1",
              "displayName": "Tester",
              "handle": "tester",
              "xp": 10,
              "level": 1,
              "streakDays": 0,
              "freezeTokens": 0,
              "dailyGoalXp": 20,
              "dailyXpEarned": 0,
              "weeklyXp": 10,
              "activeTrackId": "az-900",
              "appliedEconomyOperations": ["operation::quiz::legacy"]
            }
            """;

        var restored = JsonSerializer.Deserialize<UserProfileDto>(
            legacyJson,
            SerializerOptions());

        restored!.AppliedEconomyOperations.Should()
            .ContainSingle("operation::quiz::legacy");
        restored.EconomyReceipts.Should().BeNull();
    }

    [Fact]
    public void Exam_ttl_and_item_type_use_the_production_wire_shape()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        var exam = new ExamRecord(
            "exam::1",
            "user-1",
            "1",
            "az-900",
            ["item-1"],
            now,
            300,
            now.AddMinutes(5),
            86_700);

        var examJson = JsonSerializer.Serialize(exam, SerializerOptions());
        var itemTypeJson = JsonSerializer.Serialize(ItemType.MatchPairs, SerializerOptions());

        examJson.Should().Contain("\"ttl\":86700");
        itemTypeJson.Should().Be("\"matchPairs\"");
        JsonSerializer.Deserialize<ExamRecord>(examJson, SerializerOptions())!.Ttl.Should().Be(86_700);
    }

    [Fact]
    public void Legacy_attempts_remain_readable_and_new_attempts_pin_content_release()
    {
        const string legacyJson = """
            {
              "id": "attempt::legacy",
              "userId": "user-1",
              "clientAttemptId": "legacy",
              "trackId": "az-900",
              "lessonId": "lesson-1",
              "startedAt": "2026-08-19T10:00:00+00:00",
              "submittedAt": "2026-08-19T10:01:00+00:00",
              "result": {
                "attemptId": "result-1",
                "scorePct": 100,
                "results": [],
                "rewards": {
                  "xpEarned": 0,
                  "newXp": 0,
                  "levelUp": false,
                  "streakExtended": false,
                  "gemsEarned": 0,
                  "achievementsUnlocked": []
                },
                "weakConcepts": [],
                "nextReviewDueAt": null
              }
            }
            """;
        var legacy = JsonSerializer.Deserialize<AttemptRecord>(legacyJson, SerializerOptions());
        legacy!.ReleaseId.Should().BeNull();
        legacy.PublicManifestId.Should().BeNull();

        var pinned = legacy with
        {
            ReleaseId =
                "sha256:6094410ae57637d55681fdeec3eae50fbfd69ba953741d069c95a478bee73f7f",
            PublicManifestId =
                "sha256:e5663734ac88ac916cff3b6e1206dc03bacf7f6d530e8b115e3f198a1e6304ee",
        };
        var json = JsonSerializer.Serialize(pinned, SerializerOptions());

        json.Should().Contain("\"releaseId\"");
        json.Should().Contain("\"publicManifestId\"");
        JsonSerializer.Deserialize<AttemptRecord>(json, SerializerOptions())
            .Should().BeEquivalentTo(pinned);
    }

    [Fact]
    public void Durable_operation_round_trips_steps_status_and_etag()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        var operation = new EconomyOperationRecord(
            EconomyOperationRecord.IdFor("quiz", "a1"),
            "user-1",
            "quiz",
            "a1",
            "{\"attemptId\":\"result-1\"}",
            ["profile", "leaderboard", "events"],
            ["profile"],
            EconomyOperationRecord.PendingStatus,
            now,
            now,
            OutcomeJson: "{\"attemptId\":\"result-1\"}")
        {
            ETag = "\"etag-operation\"",
        };

        var json = JsonSerializer.Serialize(operation, SerializerOptions());
        var restored = JsonSerializer.Deserialize<EconomyOperationRecord>(json, SerializerOptions());

        json.Should().Contain("\"requiredSteps\"");
        json.Should().Contain("\"completedSteps\"");
        json.Should().Contain("\"outcomeJson\"");
        json.Should().Contain("\"ttl\":-1");
        json.Should().Contain("\"_etag\"");
        restored.Should().BeEquivalentTo(operation);
    }
}
