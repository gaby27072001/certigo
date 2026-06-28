using FluentAssertions;
using Microlingo.Application.Services;
using Microlingo.Domain.Content;
using Xunit;

namespace Microlingo.Application.Tests;

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
        az104.Provider.Should().Be("microsoft");
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

    [Fact]
    public async Task GetCatalogAsync_ranks_all_six_levels_in_order()
    {
        var content = new InMemoryContentRepository();
        content.AddTrack(MakeTrack("t-master", "C-MASTER", "Master", "master", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("t-expert", "C-EXPERT", "Expert", "expert", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("t-specialty", "C-SPECIALTY", "Specialty", "specialty", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("t-professional", "C-PROFESSIONAL", "Professional", "professional", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("t-associate", "C-ASSOCIATE", "Associate", "associate", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("t-fundamentals", "C-FUNDAMENTALS", "Fundamentals", "fundamentals", units: 1, lessonsPerUnit: 1));
        var service = new ContentService(content);

        var catalog = await service.GetCatalogAsync();

        catalog.Tracks.Select(t => t.Level).Should().Equal(
            "fundamentals", "associate", "professional", "specialty", "expert", "master");
    }

    [Fact]
    public async Task GetCatalogAsync_breaks_level_ties_by_provider_then_code()
    {
        var content = new InMemoryContentRepository();
        content.AddTrack(MakeTrack("oracle-x", "OCI-1", "Oracle one", "associate", units: 1, lessonsPerUnit: 1, provider: "oracle"));
        content.AddTrack(MakeTrack("aws-b", "SAA-C03", "AWS b", "associate", units: 1, lessonsPerUnit: 1, provider: "aws"));
        content.AddTrack(MakeTrack("aws-a", "DVA-C02", "AWS a", "associate", units: 1, lessonsPerUnit: 1, provider: "aws"));
        var service = new ContentService(content);

        var catalog = await service.GetCatalogAsync();

        // Same level -> provider asc (aws before oracle), then code asc within provider.
        catalog.Tracks.Select(t => t.Code).Should().Equal("DVA-C02", "SAA-C03", "OCI-1");
        catalog.Tracks.Select(t => t.Provider).Should().Equal("aws", "aws", "oracle");
    }

    private static Track MakeTrack(string id, string code, string title, string? level, int units, int lessonsPerUnit, string provider = "microsoft")
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
            Level: level,
            Provider: provider);
    }
}
