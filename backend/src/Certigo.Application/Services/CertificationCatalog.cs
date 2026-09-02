using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Certigo.Application.Services;

public static class CertificationCatalogSchemas
{
    public const string SourceV1 = "certigo.certification-catalog/v1";
    public const string AppV2 = "urn:certigo:contract:certification-catalog:app:v2";

    // Kept on the wire until deployed mobile versions accept AppV2.
    public const string LegacyAppV2 = "certigo.app-certification-catalog/v2";
    public const string EmittedAppV2 = LegacyAppV2;
}

public sealed record CertificationCatalogDocument(
    string Schema,
    DateOnly AsOf,
    CertificationCatalogFreshness Freshness,
    IReadOnlyList<CertificationProviderDefinition> Providers,
    IReadOnlyList<CertificationCatalogEntry> Certifications);

public sealed record CertificationCatalogFreshness(
    int MaxAgeDays,
    DateOnly ReviewDueOn);

public sealed record CertificationProviderDefinition(
    string Id,
    string Name,
    string Namespace,
    string? OfficialCatalogUrl,
    IReadOnlyList<string> SourceHosts,
    DateOnly? CheckedOn);

public sealed record CertificationCatalogEntry(
    string Id,
    string Provider,
    string Slug,
    string? OfficialCode,
    string OfficialSlug,
    string Title,
    string Level,
    string Status,
    string OfficialUrl,
    CertificationGuide Guide,
    CertificationBlueprint Blueprint,
    CertificationProvenance Provenance,
    CertificationLifecycle? Lifecycle = null);

public sealed record CertificationGuide(
    string Url,
    string? Version,
    DateOnly? PublishedOn,
    string? VersionSource,
    string? RevisionToken);

public sealed record CertificationBlueprint(
    string Version,
    IReadOnlyList<CertificationObjective> Objectives);

public sealed record CertificationObjective(
    string Id,
    string Title,
    decimal WeightPercent,
    string WeightType);

public sealed record CertificationLifecycle(
    DateOnly? ReviewOn = null,
    DateOnly? LastExamOn = null,
    IReadOnlyList<string>? Replaces = null,
    string? Successor = null,
    string? Note = null);

public sealed record CertificationProvenance(
    DateOnly CheckedOn,
    IReadOnlyList<CertificationSource> Sources);

public sealed record CertificationSource(
    string Kind,
    string Url);

public interface ICertificationRegistry
{
    string SourceSchema { get; }
    string Version { get; }
    DateOnly? AsOf { get; }
    CertificationCatalogFreshness? Freshness { get; }
    IReadOnlyList<CertificationProviderDefinition> Providers { get; }
    IReadOnlyList<CertificationCatalogEntry> Entries { get; }
}

/// <summary>
/// Safe production boundary until the certigo-content package importer injects
/// the canonical public catalog. Test fixtures must never be registered here.
/// </summary>
public sealed class EmptyCertificationRegistry : ICertificationRegistry
{
    public static EmptyCertificationRegistry Instance { get; } = new();

    private EmptyCertificationRegistry()
    {
    }

    public string SourceSchema => CertificationCatalogSchemas.SourceV1;
    public string Version => string.Empty;
    public DateOnly? AsOf => null;
    public CertificationCatalogFreshness? Freshness => null;
    public IReadOnlyList<CertificationProviderDefinition> Providers =>
        Array.Empty<CertificationProviderDefinition>();
    public IReadOnlyList<CertificationCatalogEntry> Entries => Array.Empty<CertificationCatalogEntry>();
}

public sealed class CertificationCatalogParser
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public CertificationCatalogDocument Parse(string json)
    {
        CertificationCatalogDocument document;
        try
        {
            document = JsonSerializer.Deserialize<CertificationCatalogDocument>(json, SerializerOptions)
                ?? throw new InvalidDataException("Canonical certification catalog is empty.");
        }
        catch (JsonException exception)
        {
            throw new InvalidDataException("Canonical certification catalog JSON is invalid.", exception);
        }

        var errors = CertificationCatalogValidator.Validate(document);
        if (errors.Count > 0)
        {
            throw new InvalidDataException(
                $"Canonical certification catalog is invalid:{Environment.NewLine}"
                + string.Join(Environment.NewLine, errors.Select(error => $"- {error}")));
        }

        return document;
    }
}

public sealed class CertificationCatalogAdapter : ICertificationRegistry
{
    private readonly CertificationCatalogDocument _document;

    public CertificationCatalogAdapter(CertificationCatalogDocument document)
    {
        var errors = CertificationCatalogValidator.Validate(document);
        if (errors.Count > 0)
        {
            throw new InvalidDataException(
                $"Canonical certification catalog is invalid:{Environment.NewLine}"
                + string.Join(Environment.NewLine, errors.Select(error => $"- {error}")));
        }

        _document = document;
    }

    public string SourceSchema => _document.Schema;
    public string Version => _document.AsOf.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    public DateOnly? AsOf => _document.AsOf;
    public CertificationCatalogFreshness? Freshness => _document.Freshness;
    public IReadOnlyList<CertificationProviderDefinition> Providers => _document.Providers;
    public IReadOnlyList<CertificationCatalogEntry> Entries => _document.Certifications;
}

public static partial class CertificationCatalogValidator
{
    private static readonly HashSet<string> ProviderIds = new(StringComparer.Ordinal)
    {
        "aws",
        "gcp",
        "microsoft",
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
        "announced",
        "active",
        "active-retiring",
        "retired",
        "replaced",
    };

    private static readonly HashSet<string> WeightTypes = new(StringComparer.Ordinal)
    {
        "exact",
        "approximate",
    };

    private static readonly HashSet<string> SourceKinds = new(StringComparer.Ordinal)
    {
        "certification-page",
        "exam-guide",
        "lifecycle",
    };

    private static readonly HashSet<string> VersionSources = new(StringComparer.Ordinal)
    {
        "change-history",
        "document-header",
        "document-title",
        "filename",
    };

    public static IReadOnlyList<string> Validate(CertificationCatalogDocument document)
    {
        var errors = new List<string>();
        if (document.Schema != CertificationCatalogSchemas.SourceV1)
            errors.Add($"schema must be '{CertificationCatalogSchemas.SourceV1}', got '{document.Schema}'.");
        if (document.AsOf == default)
            errors.Add("asOf is required.");
        if (document.Freshness is null)
        {
            errors.Add("freshness is required.");
        }
        else
        {
            if (document.Freshness.MaxAgeDays <= 0)
                errors.Add("freshness.maxAgeDays must be positive.");
            if (document.Freshness.ReviewDueOn == default)
                errors.Add("freshness.reviewDueOn is required.");
        }

        var providersById = ValidateProviders(document.Providers, errors);
        if (document.Certifications is null || document.Certifications.Count == 0)
        {
            errors.Add("certifications must contain at least one entry.");
            return errors;
        }

        var ids = new HashSet<string>(StringComparer.Ordinal);
        var officialCodes = new HashSet<string>(StringComparer.Ordinal);
        foreach (var entry in document.Certifications)
        {
            ValidateEntry(entry, document.AsOf, providersById, ids, officialCodes, errors);
        }

        return errors;
    }

    private static IReadOnlyDictionary<string, CertificationProviderDefinition> ValidateProviders(
        IReadOnlyList<CertificationProviderDefinition>? providers,
        List<string> errors)
    {
        if (providers is null || providers.Count == 0)
        {
            errors.Add("providers must contain canonical provider definitions.");
            return new Dictionary<string, CertificationProviderDefinition>(StringComparer.Ordinal);
        }

        var byId = new Dictionary<string, CertificationProviderDefinition>(StringComparer.Ordinal);
        foreach (var provider in providers)
        {
            if (!ProviderIds.Contains(provider.Id))
                errors.Add($"provider '{provider.Id}' is unsupported.");
            if (!byId.TryAdd(provider.Id, provider))
                errors.Add($"provider '{provider.Id}' is duplicated.");
            if (provider.Namespace != provider.Id)
                errors.Add($"provider '{provider.Id}' namespace must match its id.");
            if (string.IsNullOrWhiteSpace(provider.Name))
                errors.Add($"provider '{provider.Id}' name is required.");
            if (provider.SourceHosts is null || provider.SourceHosts.Count == 0)
                errors.Add($"provider '{provider.Id}' sourceHosts must not be empty.");
            else if (provider.SourceHosts.Any(host => !HostRegex().IsMatch(host)))
                errors.Add($"provider '{provider.Id}' sourceHosts contains an invalid host.");
            if (provider.OfficialCatalogUrl is not null
                && !IsAllowedOfficialUrl(
                    provider.OfficialCatalogUrl,
                    provider.SourceHosts ?? Array.Empty<string>()))
            {
                errors.Add($"provider '{provider.Id}' officialCatalogUrl is not on an allowed HTTPS host.");
            }
        }

        foreach (var providerId in ProviderIds)
        {
            if (!byId.ContainsKey(providerId))
                errors.Add($"provider '{providerId}' is required.");
        }

        return byId;
    }

    private static void ValidateEntry(
        CertificationCatalogEntry entry,
        DateOnly asOf,
        IReadOnlyDictionary<string, CertificationProviderDefinition> providersById,
        HashSet<string> ids,
        HashSet<string> officialCodes,
        List<string> errors)
    {
        if (!ids.Add(entry.Id))
            errors.Add($"{entry.Id}: duplicate id.");
        if (!CatalogIdRegex().IsMatch(entry.Id))
            errors.Add($"{entry.Id}: id must be a canonical provider:slug identifier.");
        if (!providersById.TryGetValue(entry.Provider, out var provider))
            errors.Add($"{entry.Id}: unsupported provider '{entry.Provider}'.");
        if (!entry.Id.StartsWith($"{entry.Provider}:", StringComparison.Ordinal))
            errors.Add($"{entry.Id}: id must start with provider '{entry.Provider}:'.");
        if (!SlugRegex().IsMatch(entry.Slug))
            errors.Add($"{entry.Id}: slug must be a lowercase slug.");
        if (entry.Id != $"{entry.Provider}:{entry.Slug}")
            errors.Add($"{entry.Id}: id must equal provider plus slug.");
        if (!SlugRegex().IsMatch(entry.OfficialSlug))
            errors.Add($"{entry.Id}: officialSlug must be a lowercase slug.");
        if (string.IsNullOrWhiteSpace(entry.Title))
            errors.Add($"{entry.Id}: title is required.");
        if (!Levels.Contains(entry.Level))
            errors.Add($"{entry.Id}: unsupported level '{entry.Level}'.");
        if (!Statuses.Contains(entry.Status))
            errors.Add($"{entry.Id}: unsupported status '{entry.Status}'.");
        if (entry.OfficialCode is not null)
        {
            if (!ExamCodeRegex().IsMatch(entry.OfficialCode))
                errors.Add($"{entry.Id}: officialCode '{entry.OfficialCode}' has an invalid format.");
            if (!officialCodes.Add($"{entry.Provider}:{entry.OfficialCode}"))
                errors.Add($"{entry.Id}: duplicate officialCode '{entry.OfficialCode}' for {entry.Provider}.");
        }

        var sourceHosts = provider?.SourceHosts ?? Array.Empty<string>();
        if (!IsAllowedOfficialUrl(entry.OfficialUrl, sourceHosts))
            errors.Add($"{entry.Id}: officialUrl is not on an allowed provider HTTPS host.");
        if (entry.Guide is null)
        {
            errors.Add($"{entry.Id}: guide is required.");
        }
        else
        {
            if (!IsAllowedOfficialUrl(entry.Guide.Url, sourceHosts))
                errors.Add($"{entry.Id}: guide.url is not on an allowed provider HTTPS host.");
            if (entry.Guide.PublishedOn > asOf)
                errors.Add($"{entry.Id}: guide.publishedOn cannot be later than asOf.");
            if (entry.Guide.VersionSource is not null
                && !VersionSources.Contains(entry.Guide.VersionSource))
            {
                errors.Add($"{entry.Id}: unsupported guide.versionSource '{entry.Guide.VersionSource}'.");
            }
        }

        ValidateBlueprint(entry, errors);
        ValidateLifecycle(entry, errors);
        ValidateProvenance(entry, sourceHosts, errors);
    }

    private static void ValidateBlueprint(CertificationCatalogEntry entry, List<string> errors)
    {
        if (entry.Blueprint is null)
        {
            errors.Add($"{entry.Id}: blueprint is required.");
            return;
        }

        if (string.IsNullOrWhiteSpace(entry.Blueprint.Version))
            errors.Add($"{entry.Id}: blueprint.version is required.");
        if (entry.Blueprint.Objectives is null || entry.Blueprint.Objectives.Count == 0)
        {
            errors.Add($"{entry.Id}: blueprint.objectives must not be empty.");
            return;
        }

        var objectiveIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var objective in entry.Blueprint.Objectives)
        {
            if (!objectiveIds.Add(objective.Id))
                errors.Add($"{entry.Id}: duplicate objective id '{objective.Id}'.");
            if (!ObjectiveIdRegex().IsMatch(objective.Id))
                errors.Add($"{entry.Id}: invalid objective id '{objective.Id}'.");
            if (string.IsNullOrWhiteSpace(objective.Title))
                errors.Add($"{entry.Id}: objective '{objective.Id}' title is required.");
            if (objective.WeightPercent <= 0 || objective.WeightPercent > 100)
                errors.Add($"{entry.Id}: objective '{objective.Id}' weightPercent must be in (0, 100].");
            if (!WeightTypes.Contains(objective.WeightType))
                errors.Add($"{entry.Id}: objective '{objective.Id}' has unsupported weightType.");
        }
    }

    private static void ValidateLifecycle(CertificationCatalogEntry entry, List<string> errors)
    {
        if (entry.Lifecycle is null)
            return;

        if (entry.Lifecycle.Replaces is not null)
        {
            foreach (var replacedId in entry.Lifecycle.Replaces)
            {
                if (!CatalogIdRegex().IsMatch(replacedId))
                    errors.Add($"{entry.Id}: lifecycle.replaces contains invalid id '{replacedId}'.");
            }
        }

        if (entry.Lifecycle.Successor is not null
            && !CatalogIdRegex().IsMatch(entry.Lifecycle.Successor))
        {
            errors.Add($"{entry.Id}: lifecycle.successor is not a canonical id.");
        }
    }

    private static void ValidateProvenance(
        CertificationCatalogEntry entry,
        IReadOnlyList<string> sourceHosts,
        List<string> errors)
    {
        if (entry.Provenance is null)
        {
            errors.Add($"{entry.Id}: provenance is required.");
            return;
        }

        if (entry.Provenance.CheckedOn == default)
            errors.Add($"{entry.Id}: provenance.checkedOn is required.");
        if (entry.Provenance.Sources is null || entry.Provenance.Sources.Count < 2)
        {
            errors.Add($"{entry.Id}: provenance.sources must contain at least two sources.");
            return;
        }

        foreach (var source in entry.Provenance.Sources)
        {
            if (!SourceKinds.Contains(source.Kind))
                errors.Add($"{entry.Id}: provenance source kind '{source.Kind}' is unsupported.");
            if (!IsAllowedOfficialUrl(source.Url, sourceHosts))
                errors.Add($"{entry.Id}: provenance source is not on an allowed provider HTTPS host.");
        }
    }

    private static bool IsAllowedOfficialUrl(string value, IReadOnlyList<string> allowedHosts)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
            return false;

        return allowedHosts.Any(host => string.Equals(uri.Host, host, StringComparison.OrdinalIgnoreCase));
    }

    [GeneratedRegex(@"^(aws|gcp|microsoft):[a-z0-9]+(?:-[a-z0-9]+)*$", RegexOptions.CultureInvariant)]
    private static partial Regex CatalogIdRegex();

    [GeneratedRegex(@"^[a-z0-9]+(?:-[a-z0-9]+)*$", RegexOptions.CultureInvariant)]
    private static partial Regex SlugRegex();

    [GeneratedRegex(@"^(domain|section)-[1-9][0-9]*$", RegexOptions.CultureInvariant)]
    private static partial Regex ObjectiveIdRegex();

    [GeneratedRegex(@"^[A-Z0-9]+(?:-[A-Z0-9]+)*$", RegexOptions.CultureInvariant)]
    private static partial Regex ExamCodeRegex();

    [GeneratedRegex(@"^[a-z0-9.-]+$", RegexOptions.CultureInvariant)]
    private static partial Regex HostRegex();
}
