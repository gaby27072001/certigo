using FluentAssertions;
using Certigo.Application.Dtos;
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

        // Fundamentals first, including the active AI-901 successor, then associate.
        catalog.Tracks.Select(t => t.Code).Should().Equal("AI-900", "AI-901", "AZ-900", "AZ-104");

        var az104 = catalog.Tracks.Single(t => t.Code == "AZ-104");
        az104.Level.Should().Be("associate");
        az104.UnitCount.Should().Be(3);
        az104.LessonCount.Should().Be(12);
        az104.Title.Should().Be("Microsoft Azure Administrator");
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
    public async Task GetCatalogAsync_merges_planned_metadata_without_exposing_it_as_learning_content()
    {
        var content = new InMemoryContentRepository();
        content.AddTrack(MakeTrack("az-900", "AZ-900", "Azure Fundamentals", "fundamentals", 1, 2));
        var registry = new StubCertificationRegistry(
            new CertificationCatalogEntry(
                Id: "aws-aif-c01",
                Provider: "aws",
                Family: "ai",
                Code: "AIF-C01",
                Title: "AWS Certified AI Practitioner",
                Level: "foundational",
                Status: "active",
                ContentStatus: "planned",
                OfficialUrl: "https://aws.amazon.com/certification/certified-ai-practitioner/"));
        var service = new ContentService(content, registry);

        var catalog = await service.GetCatalogAsync();

        catalog.Tracks.Should().HaveCount(2);
        var microsoft = catalog.Tracks.Single(track => track.Id == "az-900");
        microsoft.Provider.Should().Be("microsoft");
        microsoft.CertificationLevel.Should().Be("foundational");
        microsoft.ContentStatus.Should().Be("available");

        var aws = catalog.Tracks.Single(track => track.Id == "aws-aif-c01");
        aws.Provider.Should().Be("aws");
        aws.ContentStatus.Should().Be("planned");
        aws.UnitCount.Should().Be(0);
        aws.LessonCount.Should().Be(0);
        aws.CatalogVersion.Should().Be("2026-08-17");
    }

    [Fact]
    public async Task GetCatalogAsync_overlays_official_blueprints_without_changing_authored_content()
    {
        var content = new InMemoryContentRepository();
        content.AddTrack(MakeTrack("az-900", "AZ-900", "Old AZ title", "fundamentals", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("dp-900", "DP-900", "Old DP title", "fundamentals", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("az-104", "AZ-104", "Old admin title", "associate", units: 1, lessonsPerUnit: 1));
        content.AddTrack(MakeTrack("ai-900", "AI-900", "Old AI title", "fundamentals", units: 1, lessonsPerUnit: 1));
        var service = new ContentService(content);

        var catalog = await service.GetCatalogAsync();

        catalog.Tracks.Single(t => t.Code == "AZ-900").Should().Match<TrackSummaryDto>(t =>
            t.Title == "Microsoft Azure Fundamentals" &&
            t.BlueprintDate == new DateOnly(2026, 7, 20));
        catalog.Tracks.Single(t => t.Code == "DP-900").BlueprintDate.Should().Be(new DateOnly(2026, 7, 21));
        catalog.Tracks.Single(t => t.Code == "AZ-104").BlueprintDate.Should().Be(new DateOnly(2026, 4, 17));

        var ai900 = catalog.Tracks.Single(t => t.Code == "AI-900");
        ai900.BlueprintDate.Should().Be(new DateOnly(2025, 5, 2));
        ai900.Lifecycle.Should().Be("retired");
        ai900.LifecycleNote.Should().Contain("30 juin 2026");
        ai900.ReplacementCode.Should().Be("AI-901");
        ai900.LearningAvailable.Should().BeTrue();
        ai900.Status.Should().Be("retired");
        ai900.ContentStatus.Should().Be("available");
        ai900.Provider.Should().Be("microsoft");

        var ai901 = catalog.Tracks.Single(t => t.Code == "AI-901");
        ai901.BlueprintDate.Should().Be(new DateOnly(2026, 4, 15));
        ai901.Lifecycle.Should().Be("active");
        ai901.LearningAvailable.Should().BeFalse();
        ai901.Status.Should().Be("active");
        ai901.ContentStatus.Should().Be("planned");
        ai901.Provider.Should().Be("microsoft");
        ai901.Domains.Should().HaveCount(2);
        ai901.Domains!.Select(d => d.Name).Should().Contain("Implement AI solutions by using Microsoft Foundry");
        ai901.MigrationNote.Should().Contain("remplace AI-900");

        foreach (var track in catalog.Tracks)
        {
            track.Domains.Should().NotBeNullOrEmpty();
            var domains = track.Domains!;
            domains.Should().OnlyContain(d =>
                d.MinWeightPct > 0 && d.MinWeightPct <= d.MaxWeightPct && d.MaxWeightPct <= 100);
            domains.Sum(d => d.MinWeightPct).Should().BeLessThanOrEqualTo(100);
            domains.Sum(d => d.MaxWeightPct).Should().BeGreaterThanOrEqualTo(100);
            track.StudyGuideUrl.Should().StartWith("https://learn.microsoft.com/");
            track.StudyGuideUrl.Should().EndWith(track.Code.ToLowerInvariant());
            track.ExamUrl.Should().StartWith("https://learn.microsoft.com/");
            track.Prerequisites.Should().NotBeNullOrWhiteSpace();
        }
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

    private sealed class StubCertificationRegistry(params CertificationCatalogEntry[] entries)
        : ICertificationRegistry
    {
        public string Version => "2026-08-17";
        public IReadOnlyList<CertificationCatalogEntry> Entries => entries;
    }
}
