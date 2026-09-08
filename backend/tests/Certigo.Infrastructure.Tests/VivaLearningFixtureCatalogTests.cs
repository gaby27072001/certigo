using Certigo.Infrastructure.Learning;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class VivaLearningFixtureCatalogTests
{
    [Fact]
    public void Embedded_catalog_loads_provider_and_learning_content_without_network()
    {
        var catalog = new EmbeddedVivaLearningFixtureCatalog();

        catalog.Provider.Id.Should().Be("11111111-1111-1111-1111-111111111111");
        catalog.Provider.IsCourseActivitySyncEnabled.Should().BeTrue();
        catalog.LearningContent.Should().ContainSingle();
        catalog.LearningContent[0].Id.Should()
            .Be("22222222-2222-2222-2222-222222222222");
        catalog.LearningContent[0].TrackId.Should().Be("az-900");
        catalog.LearningContent[0].LessonId.Should().Be("az900-l-cloud-benefits");
    }
}
