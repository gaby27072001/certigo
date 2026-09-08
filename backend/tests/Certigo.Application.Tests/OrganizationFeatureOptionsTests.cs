using Certigo.Application.Abstractions;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class OrganizationFeatureOptionsTests
{
    [Theory]
    [InlineData(null, OrganizationFeatureMode.Off)]
    [InlineData("", OrganizationFeatureMode.Off)]
    [InlineData("off", OrganizationFeatureMode.Off)]
    [InlineData("OFF", OrganizationFeatureMode.Off)]
    [InlineData("shadow", OrganizationFeatureMode.Shadow)]
    [InlineData("SHADOW", OrganizationFeatureMode.Shadow)]
    public void Feature_mode_accepts_only_off_and_shadow(
        string? configured,
        OrganizationFeatureMode expected)
    {
        OrganizationFeatureOptions.Parse(configured).Mode.Should().Be(expected);
    }

    [Theory]
    [InlineData("read")]
    [InlineData("write")]
    [InlineData("enabled")]
    [InlineData("on")]
    public void Future_or_unknown_feature_modes_fail_fast(string configured)
    {
        var action = () => OrganizationFeatureOptions.Parse(configured);

        action.Should().Throw<InvalidOperationException>()
            .WithMessage("*off*shadow*");
    }

    [Theory]
    [InlineData(OrganizationFeatureMode.Off)]
    [InlineData(OrganizationFeatureMode.Shadow)]
    public void Neither_off_nor_shadow_enables_the_http_surface(OrganizationFeatureMode mode)
    {
        new OrganizationFeatureOptions(mode).HttpSurfaceEnabled.Should().BeFalse();
    }
}
