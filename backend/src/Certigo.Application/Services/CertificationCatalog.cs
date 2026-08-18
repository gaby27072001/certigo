using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Certigo.Application.Services;

public sealed record CertificationCatalogDocument(
    int SchemaVersion,
    DateOnly AsOf,
    IReadOnlyList<string> Sources,
    IReadOnlyList<CertificationCatalogEntry> Certifications);

public sealed record CertificationCatalogEntry(
    string Id,
    string Provider,
    string Family,
    string Code,
    string Title,
    string Level,
    string Status,
    string ContentStatus,
    string OfficialUrl,
    string? ExamGuideUrl = null,
    DateOnly? BlueprintPublishedOn = null,
    string? BlueprintVersion = null,
    IReadOnlyList<string>? Languages = null,
    int? DurationMinutes = null,
    string? Prerequisites = null,
    IReadOnlyList<string>? Aliases = null,
    string? ReplacedBy = null,
    DateOnly? RetiresOn = null,
    DateOnly? RetiredOn = null);

public interface ICertificationRegistry
{
    string Version { get; }
    IReadOnlyList<CertificationCatalogEntry> Entries { get; }
}

public sealed class EmptyCertificationRegistry : ICertificationRegistry
{
    public static EmptyCertificationRegistry Instance { get; } = new();

    private EmptyCertificationRegistry()
    {
    }

    public string Version => string.Empty;
    public IReadOnlyList<CertificationCatalogEntry> Entries => Array.Empty<CertificationCatalogEntry>();
}

public sealed class EmbeddedCertificationRegistry : ICertificationRegistry
{
    private const string ResourceSuffix = "official-certifications-2026-08-17.json";
    private readonly CertificationCatalogDocument _document;

    public EmbeddedCertificationRegistry()
        : this(LoadEmbeddedDocument())
    {
    }

    public EmbeddedCertificationRegistry(CertificationCatalogDocument document)
    {
        var errors = CertificationCatalogValidator.Validate(document);
        if (errors.Count > 0)
        {
            throw new InvalidDataException(
                $"Official certification catalog is invalid:{Environment.NewLine}"
                + string.Join(Environment.NewLine, errors.Select(error => $"- {error}")));
        }

        _document = document;
    }

    public string Version => _document.AsOf.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    public IReadOnlyList<CertificationCatalogEntry> Entries => _document.Certifications;

    private static CertificationCatalogDocument LoadEmbeddedDocument()
    {
        var assembly = typeof(EmbeddedCertificationRegistry).Assembly;
        var resourceName = assembly.GetManifestResourceNames()
            .SingleOrDefault(name => name.EndsWith(ResourceSuffix, StringComparison.Ordinal))
            ?? throw new InvalidDataException($"Embedded catalog resource '{ResourceSuffix}' was not found.");

        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidDataException($"Embedded catalog resource '{resourceName}' could not be opened.");
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        return JsonSerializer.Deserialize<CertificationCatalogDocument>(stream, options)
            ?? throw new InvalidDataException("Embedded certification catalog is empty.");
    }
}

public static partial class CertificationCatalogValidator
{
    private static readonly HashSet<string> Providers = new(StringComparer.Ordinal)
    {
        "aws",
        "gcp",
    };

    private static readonly HashSet<string> Levels = new(StringComparer.Ordinal)
    {
        "foundational",
        "associate",
        "professional",
        "specialty",
    };

    private static readonly HashSet<string> Statuses = new(StringComparer.Ordinal)
    {
        "active",
        "retired",
    };

    private static readonly HashSet<string> ContentStatuses = new(StringComparer.Ordinal)
    {
        "available",
        "planned",
    };

    public static IReadOnlyList<string> Validate(CertificationCatalogDocument document)
    {
        var errors = new List<string>();
        if (document.SchemaVersion != 1)
            errors.Add($"schemaVersion must be 1, got {document.SchemaVersion}.");
        if (document.AsOf == default)
            errors.Add("asOf is required.");
        if (document.Sources is null || document.Sources.Count == 0)
            errors.Add("sources must contain at least one official catalog URL.");
        else
        {
            foreach (var source in document.Sources)
            {
                if (!IsOfficialUrl(source, provider: null))
                    errors.Add($"source URL is not an approved official HTTPS URL: {source}");
            }
        }

        if (document.Certifications is null || document.Certifications.Count == 0)
        {
            errors.Add("certifications must contain at least one entry.");
            return errors;
        }

        var ids = new HashSet<string>(StringComparer.Ordinal);
        var codes = new HashSet<string>(StringComparer.Ordinal);
        foreach (var entry in document.Certifications)
        {
            ValidateEntry(entry, document.AsOf, ids, codes, errors);
        }

        var knownIds = document.Certifications.Select(entry => entry.Id).ToHashSet(StringComparer.Ordinal);
        foreach (var entry in document.Certifications)
        {
            if (entry.ReplacedBy is not null && !knownIds.Contains(entry.ReplacedBy))
                errors.Add($"{entry.Id}: replacedBy '{entry.ReplacedBy}' is not present in the catalog.");
        }

        return errors;
    }

    private static void ValidateEntry(
        CertificationCatalogEntry entry,
        DateOnly asOf,
        HashSet<string> ids,
        HashSet<string> codes,
        List<string> errors)
    {
        if (!ids.Add(entry.Id))
            errors.Add($"{entry.Id}: duplicate id.");
        if (!CatalogIdRegex().IsMatch(entry.Id))
            errors.Add($"{entry.Id}: id must be a lowercase provider-prefixed slug.");
        if (!Providers.Contains(entry.Provider))
            errors.Add($"{entry.Id}: unsupported provider '{entry.Provider}'.");
        if (!entry.Id.StartsWith($"{entry.Provider}-", StringComparison.Ordinal))
            errors.Add($"{entry.Id}: id must start with provider '{entry.Provider}-'.");
        if (!FamilyRegex().IsMatch(entry.Family))
            errors.Add($"{entry.Id}: family must be a lowercase slug.");
        if (string.IsNullOrWhiteSpace(entry.Title))
            errors.Add($"{entry.Id}: title is required.");
        if (!Levels.Contains(entry.Level))
            errors.Add($"{entry.Id}: unsupported level '{entry.Level}'.");
        if (!Statuses.Contains(entry.Status))
            errors.Add($"{entry.Id}: unsupported status '{entry.Status}'.");
        if (!ContentStatuses.Contains(entry.ContentStatus))
            errors.Add($"{entry.Id}: unsupported contentStatus '{entry.ContentStatus}'.");
        if (entry.ContentStatus == "available")
            errors.Add($"{entry.Id}: contentStatus must remain planned until content is authored.");

        if (entry.Provider == "aws" && string.IsNullOrWhiteSpace(entry.Code))
            errors.Add($"{entry.Id}: AWS certifications require an official exam code.");
        if (!string.IsNullOrEmpty(entry.Code))
        {
            if (!ExamCodeRegex().IsMatch(entry.Code))
                errors.Add($"{entry.Id}: exam code '{entry.Code}' has an invalid format.");
            if (!codes.Add($"{entry.Provider}:{entry.Code}"))
                errors.Add($"{entry.Id}: duplicate exam code '{entry.Code}' for {entry.Provider}.");
        }

        if (!IsOfficialUrl(entry.OfficialUrl, entry.Provider))
            errors.Add($"{entry.Id}: officialUrl is not an approved provider HTTPS URL.");
        if (entry.ExamGuideUrl is not null && !IsOfficialUrl(entry.ExamGuideUrl, entry.Provider))
            errors.Add($"{entry.Id}: examGuideUrl is not an approved provider HTTPS URL.");
        if (entry.Status == "active" && entry.RetiredOn is not null)
            errors.Add($"{entry.Id}: an active certification cannot have retiredOn.");
        if (entry.Status == "active" && entry.RetiresOn is not null && entry.RetiresOn <= asOf)
            errors.Add($"{entry.Id}: an active certification must have a future retiresOn date.");
        if (entry.Status == "retired" && entry.RetiredOn is null)
            errors.Add($"{entry.Id}: a retired certification must have retiredOn.");
        if (entry.Status == "retired" && entry.RetiredOn > asOf)
            errors.Add($"{entry.Id}: retiredOn cannot be later than the catalog asOf date.");
        if (entry.BlueprintPublishedOn > asOf)
            errors.Add($"{entry.Id}: blueprintPublishedOn cannot be later than the catalog asOf date.");
        if (entry.DurationMinutes is <= 0)
            errors.Add($"{entry.Id}: durationMinutes must be positive when supplied.");
        if (entry.Languages is not null
            && entry.Languages.Any(language => string.IsNullOrWhiteSpace(language)))
            errors.Add($"{entry.Id}: languages cannot contain blanks.");
    }

    private static bool IsOfficialUrl(string value, string? provider)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
            return false;

        return provider switch
        {
            "aws" => IsHost(uri, "aws.amazon.com")
                || IsHost(uri, "docs.aws.amazon.com")
                || IsHost(uri, "d1.awsstatic.com"),
            "gcp" => IsHost(uri, "cloud.google.com") || IsHost(uri, "services.google.com"),
            _ => IsHost(uri, "aws.amazon.com")
                || IsHost(uri, "docs.aws.amazon.com")
                || IsHost(uri, "d1.awsstatic.com")
                || IsHost(uri, "cloud.google.com")
                || IsHost(uri, "services.google.com"),
        };
    }

    private static bool IsHost(Uri uri, string expected)
        => string.Equals(uri.Host, expected, StringComparison.OrdinalIgnoreCase);

    [GeneratedRegex(@"^(aws|gcp)-[a-z0-9]+(?:-[a-z0-9]+)*$", RegexOptions.CultureInvariant)]
    private static partial Regex CatalogIdRegex();

    [GeneratedRegex(@"^[a-z0-9]+(?:-[a-z0-9]+)*$", RegexOptions.CultureInvariant)]
    private static partial Regex FamilyRegex();

    [GeneratedRegex(@"^[A-Z0-9]+(?:-[A-Z0-9]+)+$", RegexOptions.CultureInvariant)]
    private static partial Regex ExamCodeRegex();
}
