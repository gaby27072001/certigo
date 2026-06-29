using FluentAssertions;
using Certigo.Domain.Social;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class ShareCodecTests
{
    private const string Base32Upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    private const string Base32Lower = "abcdefghijklmnopqrstuvwxyz234567";

    [Fact]
    public void ReferralCode_is_deterministic_and_well_formed()
    {
        var first = ShareCodec.ReferralCode("user-1");
        var second = ShareCodec.ReferralCode("user-1");

        first.Should().Be(second);
        first.Should().HaveLength(8);
        first.Should().MatchRegex($"^[{Base32Upper}]+$");
    }

    [Fact]
    public void ReferralCode_differs_per_user()
    {
        ShareCodec.ReferralCode("user-1").Should().NotBe(ShareCodec.ReferralCode("user-2"));
    }

    [Fact]
    public void DailyShareId_is_deterministic_for_same_user_and_day()
    {
        var date = new DateOnly(2025, 1, 6);

        var first = ShareCodec.DailyShareId("user-1", date);
        var second = ShareCodec.DailyShareId("user-1", date);

        first.Should().Be(second);
        first.Should().HaveLength(12);
        first.Should().MatchRegex($"^[{Base32Lower}]+$");
    }

    [Fact]
    public void DailyShareId_differs_across_days_and_users()
    {
        var day1 = new DateOnly(2025, 1, 6);
        var day2 = new DateOnly(2025, 1, 7);

        ShareCodec.DailyShareId("user-1", day1)
            .Should().NotBe(ShareCodec.DailyShareId("user-1", day2));
        ShareCodec.DailyShareId("user-1", day1)
            .Should().NotBe(ShareCodec.DailyShareId("user-2", day1));
    }
}
