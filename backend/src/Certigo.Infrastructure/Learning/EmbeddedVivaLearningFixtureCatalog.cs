using System.Reflection;
using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Infrastructure.Learning;

public sealed class EmbeddedVivaLearningFixtureCatalog : IVivaLearningFixtureCatalog
{
    public EmbeddedVivaLearningFixtureCatalog()
    {
        Provider = Read<VivaLearningProviderDto>("provider.json");
        LearningContent = Read<VivaLearningContentFixtureDto[]>("learning-content.json");
    }

    public VivaLearningProviderDto Provider { get; }

    public IReadOnlyList<VivaLearningContentFixtureDto> LearningContent { get; }

    private static T Read<T>(string fileName)
    {
        var assembly = typeof(EmbeddedVivaLearningFixtureCatalog).Assembly;
        var resourceName = $"{typeof(EmbeddedVivaLearningFixtureCatalog).Namespace}.Fixtures.{fileName}";
        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException(
                $"Fixture resource '{resourceName}' is missing.");
        return JsonSerializer.Deserialize<T>(stream, new JsonSerializerOptions(JsonSerializerDefaults.Web))
            ?? throw new InvalidOperationException(
                $"Fixture resource '{resourceName}' is invalid.");
    }
}
