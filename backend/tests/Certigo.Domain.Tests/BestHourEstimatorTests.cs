using FluentAssertions;
using Certigo.Domain.Notifications;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class BestHourEstimatorTests
{
    [Fact]
    public void Estimate_returns_default_hour_when_histogram_is_null()
    {
        BestHourEstimator.Estimate(null).Should().Be(BestHourEstimator.DefaultHour);
    }

    [Fact]
    public void Estimate_returns_fallback_when_histogram_is_empty()
    {
        BestHourEstimator.Estimate(new int[0], fallbackHour: 8).Should().Be(8);
    }

    [Fact]
    public void Estimate_returns_fallback_when_all_zero()
    {
        BestHourEstimator.Estimate(new int[24], fallbackHour: 6).Should().Be(6);
    }

    [Fact]
    public void Estimate_returns_argmax_hour()
    {
        var histogram = new int[24];
        histogram[7] = 3;
        histogram[20] = 9;
        histogram[21] = 4;

        BestHourEstimator.Estimate(histogram).Should().Be(20);
    }

    [Fact]
    public void Estimate_breaks_ties_by_circular_distance_to_fallback()
    {
        var histogram = new int[24];
        histogram[6] = 5;
        histogram[18] = 5;

        // Fallback 19 → 18 is circularly closer than 6.
        BestHourEstimator.Estimate(histogram, fallbackHour: 19).Should().Be(18);
    }

    [Fact]
    public void Estimate_breaks_equal_distance_ties_by_lowest_hour()
    {
        var histogram = new int[24];
        histogram[11] = 5;
        histogram[13] = 5;

        // Fallback 12 → both at distance 1, lowest index wins.
        BestHourEstimator.Estimate(histogram, fallbackHour: 12).Should().Be(11);
    }

    [Fact]
    public void Estimate_tolerates_histogram_shorter_than_24()
    {
        var histogram = new[] { 0, 0, 0, 5 };

        BestHourEstimator.Estimate(histogram).Should().Be(3);
    }

    [Fact]
    public void Reinforce_on_null_seeds_single_hour()
    {
        var next = BestHourEstimator.Reinforce(null, 9);

        next.Should().HaveCount(24);
        next[9].Should().Be(8);
        next.Where((_, i) => i != 9).Should().OnlyContain(v => v == 0);
    }

    [Fact]
    public void Reinforce_decays_existing_then_adds_weight()
    {
        var histogram = new int[24];
        histogram[9] = 8;

        var next = BestHourEstimator.Reinforce(histogram, 9);

        // 8 * 7 / 8 = 7, then + 8 = 15.
        next[9].Should().Be(15);
    }

    [Fact]
    public void Reinforce_wraps_active_hour()
    {
        var next = BestHourEstimator.Reinforce(null, 26);

        next[2].Should().Be(8);
    }

    [Fact]
    public void Reinforce_always_returns_24_buckets()
    {
        var next = BestHourEstimator.Reinforce(new[] { 1, 2 }, 0);

        next.Should().HaveCount(24);
    }

    [Fact]
    public void Estimate_favours_recent_activity_over_stale_frequency()
    {
        int[]? histogram = null;
        for (var i = 0; i < 5; i++)
        {
            histogram = BestHourEstimator.Reinforce(histogram, 8);
        }

        for (var i = 0; i < 5; i++)
        {
            histogram = BestHourEstimator.Reinforce(histogram, 20);
        }

        histogram![20].Should().BeGreaterThan(histogram[8]);
        BestHourEstimator.Estimate(histogram).Should().Be(20);
    }

    [Theory]
    [InlineData(-1, 23)]
    [InlineData(0, 0)]
    [InlineData(24, 0)]
    [InlineData(25, 1)]
    [InlineData(49, 1)]
    public void Wrap_normalises_to_day(int input, int expected)
    {
        BestHourEstimator.Wrap(input).Should().Be(expected);
    }
}
