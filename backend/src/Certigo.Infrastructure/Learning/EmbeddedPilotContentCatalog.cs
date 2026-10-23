using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Learning;

public sealed class EmbeddedPilotContentCatalog : IPilotContentCatalog
{
    public const string PilotId = "responsible-ai-assistants";
    private const string ResourceSuffix = ".Learning.Fixtures.responsible-ai-assistants.json";
    private const string ExpectedSchema = "certigo.editorial.pilot/v1";
    private const string ExpectedLocale = "fr-FR";
    private const string ExpectedPurpose = "learning-not-certification";

    public async Task<PilotContentPackage?> GetAsync(
        string pilotId,
        CancellationToken cancellationToken = default)
    {
        if (!string.Equals(pilotId, PilotId, StringComparison.Ordinal))
        {
            return null;
        }

        var assembly = typeof(EmbeddedPilotContentCatalog).Assembly;
        var resourceName = assembly.GetManifestResourceNames()
            .Single(name => name.EndsWith(ResourceSuffix, StringComparison.Ordinal));
        await using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException("The editorial pilot resource is missing.");
        using var buffer = new MemoryStream();
        await stream.CopyToAsync(buffer, cancellationToken);
        var bytes = buffer.ToArray();
        using var document = JsonDocument.Parse(bytes);
        var root = document.RootElement;
        if (root.GetProperty("schema").GetString() != ExpectedSchema
            || root.GetProperty("id").GetString() != PilotId
            || root.GetProperty("locale").GetString() != ExpectedLocale
            || root.GetProperty("purpose").GetString() != ExpectedPurpose)
        {
            throw new InvalidOperationException("The embedded editorial pilot identity is invalid.");
        }

        var sources = root.GetProperty("sources").EnumerateArray()
            .Select(source => source.GetProperty("id").GetString()
                ?? throw new InvalidOperationException("The pilot contains an invalid source ID."))
            .ToHashSet(StringComparer.Ordinal);
        var lessons = root.GetProperty("lessons").EnumerateArray().ToArray();
        var lessonIds = lessons
            .Select(lesson => lesson.GetProperty("id").GetString()
                ?? throw new InvalidOperationException("The pilot contains an invalid lesson ID."))
            .ToArray();
        if (lessons.Length != 3
            || lessonIds.Distinct(StringComparer.Ordinal).Count() != lessonIds.Length
            || lessons.Any(lesson => lesson.GetProperty("sourceIds").EnumerateArray()
                .Any(sourceId => !sources.Contains(sourceId.GetString() ?? string.Empty))))
        {
            throw new InvalidOperationException(
                "The embedded editorial pilot lesson or source references are invalid.");
        }

        var digest = $"sha256:{Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant()}";
        return new PilotContentPackage(
            PilotId,
            digest,
            bytes,
            lessonIds.ToHashSet(StringComparer.Ordinal));
    }
}
