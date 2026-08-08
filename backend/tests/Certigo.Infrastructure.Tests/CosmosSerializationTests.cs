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
    public void User_profile_round_trips_camel_case_etag_and_economy_markers()
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
            AppliedEconomyOperations: ["operation::quiz::a1"])
        {
            ETag = "\"etag-1\"",
        };

        var json = JsonSerializer.Serialize(profile, SerializerOptions());
        var restored = JsonSerializer.Deserialize<UserProfileDto>(json, SerializerOptions());

        json.Should().Contain("\"displayName\"");
        using var document = JsonDocument.Parse(json);
        document.RootElement.GetProperty("_etag").GetString().Should().Be("\"etag-1\"");
        json.Should().Contain("\"appliedEconomyOperations\"");
        restored.Should().BeEquivalentTo(profile);
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
            now)
        {
            ETag = "\"etag-operation\"",
        };

        var json = JsonSerializer.Serialize(operation, SerializerOptions());
        var restored = JsonSerializer.Deserialize<EconomyOperationRecord>(json, SerializerOptions());

        json.Should().Contain("\"requiredSteps\"");
        json.Should().Contain("\"completedSteps\"");
        json.Should().Contain("\"_etag\"");
        restored.Should().BeEquivalentTo(operation);
    }
}
