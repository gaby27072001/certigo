using FluentAssertions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class ContentServiceTests
{
    [Fact]
    public async Task GetCatalogAsync_orders_by_level_then_code_and_counts_units_and_lessons()
    {
        var content = new InMemoryContentRepository();
        content.AddTrack(MakeTrack("az-104", "AZ-104", "Azure Administrator", "associate", units: 3, lessonsPerUnit: 4));
        content.AddTrack(MakeTrack("az-900", "AZ-900", "Azure Fundamentals", "fundamentals", units: 2, lessonsPerUnit: 3));
        content.AddTrack(MakeTrack("ai-900", "AI-900", "AI Fundamentals", "fundamentals", units: 2, lessonsPerUnit: 2));
        var service = new ContentService(content);

        var catalog = await service.GetCatalogAsync();

        // Fundamentals first (AI-900, AZ-900 by code), then associate (AZ-104).
        catalog.Tracks.Select(t => t.Code).Should().Equal("AI-900", "AZ-900", "AZ-104");

        var az104 = catalog.Tracks.Single(t => t.Code == "AZ-104");
        az104.Level.Should().Be("associate");
        az104.UnitCount.Should().Be(3);
        az104.LessonCount.Should().Be(12);
        az104.Title.Should().Be("Azure Administrator");
    }

    [Fact]
    public async Task GetCatalogAsync_with_no_level_sorts_last_and_maps_empty_string()
    {
        var content = new InMemoryContentRepository();
        content.AddTrack(MakeTrack("zz-000", "ZZ-000", "Unlabelled", level: null, units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("az-900", "AZ-900", "Azure Fundamentals", "fundamentals", units: 1, lessonsPerUnit: 1));
        var service = new ContentService(content);

        var catalog = await service.GetCatalogAsync();

        catalog.Tracks.Select(t => t.Code).Should().Equal("AZ-900", "ZZ-000");
        catalog.Tracks.Last().Level.Should().BeEmpty();
    }

    private static Track MakeTrack(string id, string code, string title, string? level, int units, int lessonsPerUnit)
    {
        var unitList = Enumerable.Range(0, units)
            .Select(u => new TrackUnit(
                $"u{u}",
                "d-1",
                $"Unit {u}",
                Enumerable.Range(0, lessonsPerUnit).Select(l => $"l{u}-{l}").ToArray()))
            .ToArray();
        return new Track(
            Id: id,
            Code: code,
            Title: title,
            Summary: $"Summary {code}",
            Domains: new[] { new ExamDomain("d-1", "Domain 1", 1.0) },
            Units: unitList,
            Level: level);
    }
}
