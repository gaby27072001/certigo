using System.Buffers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Certigo.Application.Abstractions;
using Certigo.Domain.Content;

namespace Certigo.Application.Services;

public sealed partial class ContentContractVerifier(
    IContentReleaseSource source,
    IContentSchemaValidator schemaValidator,
    ContentReleaseLimits limits)
{
    private static readonly JsonSerializerOptions ContractJsonOptions = CreateContractJsonOptions();
    private static readonly HashSet<string> PublicForbiddenKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "answerKey",
        "correct",
        "correctOptionIds",
        "explanation",
        "privateManifestId",
        "rationale",
        "solution",
    };

    public async Task<VerifiedContentRelease> VerifyReleaseAsync(
        string releaseId,
        CancellationToken cancellationToken = default)
    {
        EnsureDigestId(releaseId, nameof(releaseId));
        var versions = new List<ContentBlobVersion>();
        long totalBytes = 0;

        var releaseBlob = await source.ReadReleaseAsync(releaseId, cancellationToken);
        totalBytes = AddAndCheckSize(totalBytes, releaseBlob);
        EnsureImmutable(releaseBlob);
        versions.Add(ToVersion(releaseBlob));
        using var releaseJson = ParseJson(releaseBlob);
        ValidateSchema("content-release.schema.json", releaseJson.RootElement);
        var descriptor = Deserialize<ContentReleaseDescriptor>(releaseJson.RootElement, releaseBlob.Path);
        VerifyReleaseDescriptor(descriptor, releaseId, releaseJson.RootElement);

        var publicResult = await ReadPackageAsync(
            ContentArtifact.Public,
            descriptor.PublicManifestId,
            versions,
            totalBytes,
            cancellationToken);
        totalBytes = publicResult.TotalBytes;
        var privateResult = await ReadPackageAsync(
            ContentArtifact.Private,
            descriptor.PrivateManifestId,
            versions,
            totalBytes,
            cancellationToken);

        if (publicResult.Manifest.Schema != ContentReleaseContracts.PackageManifestV3
            || privateResult.Manifest.Schema != ContentReleaseContracts.PackageManifestV3)
        {
            throw Invalid(
                "certigo.content.release/v1 is valid only for paired runtime package-manifest/v3 artifacts.");
        }

        var catalog = ParseCatalog(publicResult.Resources);
        var graph = BuildGraph(catalog, publicResult.Resources, privateResult.Resources);
        ValidateGraph(graph);
        ValidateCoverage(graph, publicResult.Resources);

        return new VerifiedContentRelease(
            descriptor,
            publicResult.Manifest,
            privateResult.Manifest,
            catalog,
            graph,
            publicResult.Resources,
            privateResult.Resources,
            versions);
    }

    public ContentPackageManifest VerifyStandaloneManifest(
        ReadOnlyMemory<byte> bytes,
        ContentArtifact artifact)
    {
        using var json = ParseJson(bytes.Span, "manifest.json");
        ValidateSchema("package-manifest.schema.json", json.RootElement);
        var manifest = Deserialize<ContentPackageManifest>(json.RootElement, "manifest.json");
        VerifyManifestIdentity(manifest, json.RootElement);
        VerifyArtifact(manifest, artifact);
        return manifest;
    }

    public ContentReleaseDescriptor VerifyDescriptor(
        ReadOnlyMemory<byte> bytes,
        string requestedReleaseId)
    {
        using var json = ParseJson(bytes.Span, "release.json");
        ValidateSchema("content-release.schema.json", json.RootElement);
        var descriptor = Deserialize<ContentReleaseDescriptor>(json.RootElement, "release.json");
        VerifyReleaseDescriptor(descriptor, requestedReleaseId, json.RootElement);
        return descriptor;
    }

    public void VerifyProjectedPublic(RuntimeContentProjection projection)
    {
        EnsureUnique(
            projection.Tracks.Select(track => track.RuntimeId),
            "projected track runtime id");
        EnsureUnique(
            projection.Lessons.Select(lesson => lesson.RuntimeId),
            "projected lesson runtime id");
        EnsureUnique(
            projection.AnswerKeys.Select(answerKey => answerKey.RuntimeLessonId),
            "projected answer-key lesson id");

        foreach (var track in projection.Tracks)
        {
            EnsureUnique(track.Track.Units.Select(unit => unit.Id), $"unit id in track '{track.RuntimeId}'");
            EnsureUnique(
                track.Track.Units.SelectMany(unit => unit.Lessons),
                $"lesson reference in track '{track.RuntimeId}'");
            using var json = JsonDocument.Parse(JsonSerializer.SerializeToUtf8Bytes(
                track.Track,
                ContractJsonOptions));
            EnsurePublic(json.RootElement, $"$.tracks.{track.RuntimeId}");
        }

        foreach (var lesson in projection.Lessons)
        {
            using var json = JsonDocument.Parse(JsonSerializer.SerializeToUtf8Bytes(
                lesson.Lesson,
                ContractJsonOptions));
            EnsurePublic(json.RootElement, $"$.lessons.{lesson.RuntimeId}");
        }

        foreach (var answerKey in projection.AnswerKeys)
        {
            EnsureUnique(
                answerKey.AnswerKey.Items.Select(item => item.ItemId),
                $"answer-key item id in lesson '{answerKey.RuntimeLessonId}'");
        }
    }

    private async Task<PackageReadResult> ReadPackageAsync(
        ContentArtifact artifact,
        string manifestId,
        ICollection<ContentBlobVersion> versions,
        long currentTotalBytes,
        CancellationToken cancellationToken)
    {
        EnsureDigestId(manifestId, $"{artifact} manifest id");
        var manifestBlob = await source.ReadManifestAsync(artifact, manifestId, cancellationToken);
        var totalBytes = AddAndCheckSize(currentTotalBytes, manifestBlob);
        EnsureImmutable(manifestBlob);
        versions.Add(ToVersion(manifestBlob));

        using var manifestJson = ParseJson(manifestBlob);
        ValidateSchema("package-manifest.schema.json", manifestJson.RootElement);
        var manifest = Deserialize<ContentPackageManifest>(manifestJson.RootElement, manifestBlob.Path);
        VerifyManifestIdentity(manifest, manifestJson.RootElement);
        VerifyArtifact(manifest, artifact);
        if (!string.Equals(manifest.ManifestId, manifestId, StringComparison.Ordinal))
        {
            throw Invalid(
                $"{artifact} manifest path id '{manifestId}' does not match payload id '{manifest.ManifestId}'.");
        }

        if (manifest.FileCount != manifest.Files.Count)
        {
            throw Invalid(
                $"{artifact} manifest fileCount={manifest.FileCount} does not match files.Count={manifest.Files.Count}.");
        }

        if (manifest.FileCount > limits.MaxFiles)
        {
            throw Invalid(
                $"{artifact} manifest contains {manifest.FileCount} files; limit is {limits.MaxFiles}.");
        }

        var declaredPaths = new HashSet<string>(StringComparer.Ordinal);
        var declaredIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var file in manifest.Files)
        {
            EnsureSafeRelativePath(file.Path);
            if (!declaredPaths.Add(file.Path))
            {
                throw Invalid($"{artifact} manifest declares duplicate path '{file.Path}'.");
            }

            if (!declaredIds.Add(file.Id))
            {
                throw Invalid($"{artifact} manifest declares duplicate id '{file.Id}'.");
            }

            if (file.Size is <= 0 or > int.MaxValue || file.Size > limits.MaxFileBytes)
            {
                throw Invalid(
                    $"{artifact} file '{file.Path}' declares invalid size {file.Size}; limit is {limits.MaxFileBytes}.");
            }

            EnsureHexDigest(file.Hash, $"{artifact} file '{file.Path}' hash");
        }

        var actualPaths = await source.ListFilesAsync(artifact, manifestId, cancellationToken);
        var actualSet = actualPaths.ToHashSet(StringComparer.Ordinal);
        if (!actualSet.SetEquals(declaredPaths))
        {
            var missing = declaredPaths.Except(actualSet, StringComparer.Ordinal);
            var extra = actualSet.Except(declaredPaths, StringComparer.Ordinal);
            throw Invalid(
                $"{artifact} package file set differs from its manifest; "
                + $"missing=[{string.Join(",", missing)}], extra=[{string.Join(",", extra)}].");
        }

        var resources = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
        foreach (var file in manifest.Files.OrderBy(entry => entry.Path, StringComparer.Ordinal))
        {
            var blob = await source.ReadFileAsync(artifact, manifestId, file.Path, cancellationToken);
            totalBytes = AddAndCheckSize(totalBytes, blob);
            EnsureImmutable(blob);
            versions.Add(ToVersion(blob));
            if (blob.Content.Length != file.Size)
            {
                throw Invalid(
                    $"{artifact} file '{file.Path}' has {blob.Content.Length} bytes; expected {file.Size}.");
            }

            var actualHash = Sha256Hex(blob.Content.Span);
            if (!string.Equals(actualHash, file.Hash, StringComparison.Ordinal))
            {
                throw Invalid(
                    $"{artifact} file '{file.Path}' hash is '{actualHash}'; expected '{file.Hash}'.");
            }

            using var payload = ParseJson(blob);
            var resourceType = ResolveResourceType(manifest.Schema, file, artifact);
            ValidatePayloadSchema(resourceType, payload.RootElement);
            VerifyResourceIdentity(file, resourceType, payload.RootElement);
            if (artifact == ContentArtifact.Public)
            {
                EnsurePublic(payload.RootElement, $"$.{file.Path}");
            }

            resources.Add(file.Path, payload.RootElement.Clone());
        }

        return new PackageReadResult(manifest, resources, totalBytes);
    }

    private static CertificationCatalogDocument ParseCatalog(
        IReadOnlyDictionary<string, JsonElement> publicResources)
    {
        var catalogs = publicResources
            .Where(entry => string.Equals(
                ResourceTypeFromPath(entry.Key),
                "certificationCatalog",
                StringComparison.Ordinal))
            .Select(entry => entry.Value)
            .ToArray();
        if (catalogs.Length != 1)
        {
            throw Invalid($"Runtime package must contain exactly one certification catalog; found {catalogs.Length}.");
        }

        return new CertificationCatalogParser().Parse(catalogs[0].GetRawText());
    }

    private static CanonicalContentGraph BuildGraph(
        CertificationCatalogDocument catalog,
        IReadOnlyDictionary<string, JsonElement> publicResources,
        IReadOnlyDictionary<string, JsonElement> privateResources)
    {
        var certifications = catalog.Certifications.ToDictionary(
            entry => entry.Id,
            entry => new CanonicalCertification(
                entry.Id,
                entry.Slug,
                entry.OfficialCode,
                entry.Title,
                entry.Level,
                entry.Status,
                entry.Blueprint.Version,
                entry.Blueprint.Objectives
                    .Select(objective => new CanonicalCertificationObjective(
                        objective.Id,
                        objective.Title,
                        objective.WeightPercent))
                    .ToArray()),
            StringComparer.Ordinal);
        var tracks = new Dictionary<string, CanonicalTrackResource>(StringComparer.Ordinal);
        var domains = new Dictionary<string, CanonicalDomainResource>(StringComparer.Ordinal);
        var units = new Dictionary<string, CanonicalUnitResource>(StringComparer.Ordinal);
        var lessons = new Dictionary<string, CanonicalLessonResource>(StringComparer.Ordinal);
        var concepts = new Dictionary<string, CanonicalConceptResource>(StringComparer.Ordinal);
        var questions = new Dictionary<string, CanonicalQuestion>(StringComparer.Ordinal);
        var solutions = new Dictionary<string, CanonicalSolution>(StringComparer.Ordinal);

        foreach (var resource in publicResources)
        {
            switch (ResourceTypeFromPath(resource.Key))
            {
                case "track":
                    AddUnique(tracks, ParseTrack(resource.Value), "track");
                    break;
                case "domain":
                    AddUnique(domains, ParseDomain(resource.Value), "domain");
                    break;
                case "unit":
                    AddUnique(units, ParseUnit(resource.Value), "unit");
                    break;
                case "lesson":
                    AddUnique(lessons, ParseLesson(resource.Value), "lesson");
                    break;
                case "concept":
                    AddUnique(concepts, ParseConcept(resource.Value), "concept");
                    break;
                case "question":
                    AddUnique(questions, ParseQuestion(resource.Value), "question");
                    break;
            }
        }

        foreach (var resource in privateResources)
        {
            if (!string.Equals(ResourceTypeFromPath(resource.Key), "solution", StringComparison.Ordinal))
            {
                throw Invalid($"Private package contains non-solution resource '{resource.Key}'.");
            }

            AddUnique(solutions, ParseSolution(resource.Value), "solution");
        }

        return new CanonicalContentGraph(
            certifications,
            tracks,
            domains,
            units,
            lessons,
            concepts,
            questions,
            solutions);
    }

    private static void ValidateGraph(CanonicalContentGraph graph)
    {
        if (graph.Tracks.Count == 0)
        {
            throw Invalid("Runtime package contains no track.");
        }

        if (!graph.Questions.Keys.ToHashSet(StringComparer.Ordinal)
            .SetEquals(graph.Solutions.Keys))
        {
            throw Invalid("Runtime v4 questions and private solutions must form an exact bijection.");
        }

        var aliases = new HashSet<string>(StringComparer.Ordinal);
        foreach (var (kind, values) in new[]
                 {
                     ("track", graph.Tracks.Values.Select(value => value.LegacyId)),
                     ("domain", graph.Domains.Values.Select(value => value.LegacyId)),
                     ("unit", graph.Units.Values.Select(value => value.LegacyId)),
                     ("lesson", graph.Lessons.Values.Select(value => value.LegacyId)),
                     ("concept", graph.Concepts.Values.Select(value => value.LegacyId)),
                     ("question", graph.Questions.Values.Select(value => value.LegacyId)),
                 })
        {
            foreach (var alias in values.Where(value => !string.IsNullOrWhiteSpace(value)))
            {
                if (!aliases.Add(alias!))
                {
                    throw Invalid($"legacyId '{alias}' is duplicated (detected while validating {kind}).");
                }
            }
        }

        foreach (var question in graph.Questions.Values)
        {
            var domain = Required(graph.Domains, question.DomainId, "domain");
            var concept = Required(graph.Concepts, question.ConceptId, "concept");
            var certification = Required(graph.Certifications, question.CertificationId, "certification");
            if (!string.Equals(domain.CertificationId, question.CertificationId, StringComparison.Ordinal)
                || !string.Equals(concept.CertificationId, question.CertificationId, StringComparison.Ordinal)
                || !string.Equals(concept.DomainId, question.DomainId, StringComparison.Ordinal)
                || !string.Equals(domain.ObjectiveId, question.ObjectiveId, StringComparison.Ordinal)
                || !string.Equals(domain.BlueprintVersion, question.BlueprintVersion, StringComparison.Ordinal)
                || !string.Equals(concept.BlueprintVersion, question.BlueprintVersion, StringComparison.Ordinal)
                || !string.Equals(certification.BlueprintVersion, question.BlueprintVersion, StringComparison.Ordinal))
            {
                throw Invalid($"Question '{question.Id}' metadata is inconsistent with its graph references.");
            }

            var solution = Required(graph.Solutions, question.Id, "solution");
            EnsureUnique(
                question.Options.Select(option => option.Id),
                $"option id in question '{question.Id}'");
            var optionIds = question.Options.Select(option => option.Id).ToHashSet(StringComparer.Ordinal);
            if (solution.CorrectOptionIds.Any(id => !optionIds.Contains(id)))
            {
                throw Invalid($"Solution '{solution.Id}' references an unknown option.");
            }

            if (question.ItemType != ItemType.Multi && solution.CorrectOptionIds.Count != 1)
            {
                throw Invalid($"Question '{question.Id}' requires exactly one correct option.");
            }
        }

        foreach (var track in graph.Tracks.Values)
        {
            var certification = Required(graph.Certifications, track.CertificationId, "certification");
            if (!string.Equals(certification.BlueprintVersion, track.BlueprintVersion, StringComparison.Ordinal))
            {
                throw Invalid($"Track '{track.Id}' blueprintVersion does not match its certification.");
            }

            foreach (var domainId in track.DomainIds)
            {
                var domain = Required(graph.Domains, domainId, "domain");
                if (!string.Equals(domain.CertificationId, track.CertificationId, StringComparison.Ordinal))
                {
                    throw Invalid($"Track '{track.Id}' references a domain from another certification.");
                }
            }

            var trackDomainIds = track.DomainIds.ToHashSet(StringComparer.Ordinal);
            var objectiveIds = new HashSet<string>(StringComparer.Ordinal);
            foreach (var domainId in track.DomainIds)
            {
                var domain = Required(graph.Domains, domainId, "domain");
                if (!objectiveIds.Add(domain.ObjectiveId))
                {
                    throw Invalid(
                        $"Track '{track.Id}' references multiple domains for objective '{domain.ObjectiveId}'.");
                }
            }

            foreach (var unitId in track.UnitIds)
            {
                var unit = Required(graph.Units, unitId, "unit");
                if (!string.Equals(unit.CertificationId, track.CertificationId, StringComparison.Ordinal)
                    || !trackDomainIds.Contains(unit.DomainId))
                {
                    throw Invalid(
                        $"Track '{track.Id}' references unit '{unit.Id}' outside its declared domains.");
                }
            }

            if (IsDistributableStatus(track.Lifecycle.Status))
            {
                foreach (var domainId in track.DomainIds)
                {
                    var domain = Required(graph.Domains, domainId, "domain");
                    if (!IsDistributableStatus(domain.Lifecycle.Status))
                    {
                        throw Invalid(
                            $"Distributable track '{track.Id}' references non-distributable domain '{domain.Id}'.");
                    }
                }

                foreach (var unitId in track.UnitIds)
                {
                    var unit = Required(graph.Units, unitId, "unit");
                    if (!IsDistributableStatus(unit.Lifecycle.Status))
                    {
                        throw Invalid(
                            $"Distributable track '{track.Id}' references non-distributable unit '{unit.Id}'.");
                    }

                    foreach (var lessonId in unit.LessonIds)
                    {
                        var lesson = Required(graph.Lessons, lessonId, "lesson");
                        if (!IsDistributableStatus(lesson.Lifecycle.Status))
                        {
                            throw Invalid(
                                $"Distributable track '{track.Id}' references non-distributable lesson '{lesson.Id}'.");
                        }
                    }
                }
            }

            if (string.Equals(track.Mode, "guided", StringComparison.Ordinal) && track.UnitIds.Count == 0)
            {
                throw Invalid($"Guided track '{track.Id}' must reference at least one unit.");
            }

            if (string.Equals(track.Mode, "questionBank", StringComparison.Ordinal) && track.UnitIds.Count != 0)
            {
                throw Invalid($"Question-bank track '{track.Id}' cannot reference authored units.");
            }

            EnsureLifecycleCompatible(track.Id, track.Lifecycle.Status, certification.Status);
        }

        EnsureExactReferenceClosure(
            graph.Tracks.Values.SelectMany(track => track.DomainIds),
            graph.Domains.Keys,
            "domain");
        EnsureExactReferenceClosure(
            graph.Tracks.Values.SelectMany(track => track.UnitIds),
            graph.Units.Keys,
            "unit");
        EnsureExactReferenceClosure(
            graph.Units.Values.SelectMany(unit => unit.LessonIds),
            graph.Lessons.Keys,
            "lesson");

        foreach (var domain in graph.Domains.Values)
        {
            var certification = Required(graph.Certifications, domain.CertificationId, "certification");
            if (!string.Equals(domain.BlueprintVersion, certification.BlueprintVersion, StringComparison.Ordinal)
                || certification.Objectives.All(objective =>
                    !string.Equals(objective.Id, domain.ObjectiveId, StringComparison.Ordinal)))
            {
                throw Invalid($"Domain '{domain.Id}' does not match its certification blueprint.");
            }

            EnsureLifecycleCompatible(domain.Id, domain.Lifecycle.Status, certification.Status);
        }

        foreach (var concept in graph.Concepts.Values)
        {
            var domain = Required(graph.Domains, concept.DomainId, "domain");
            if (!string.Equals(concept.CertificationId, domain.CertificationId, StringComparison.Ordinal)
                || !string.Equals(concept.BlueprintVersion, domain.BlueprintVersion, StringComparison.Ordinal))
            {
                throw Invalid($"Concept '{concept.Id}' does not match its domain.");
            }

            var certification = Required(
                graph.Certifications,
                concept.CertificationId,
                "certification");
            EnsureLifecycleCompatible(concept.Id, concept.Lifecycle.Status, certification.Status);
        }

        foreach (var unit in graph.Units.Values)
        {
            var domain = Required(graph.Domains, unit.DomainId, "domain");
            if (!string.Equals(unit.CertificationId, domain.CertificationId, StringComparison.Ordinal)
                || !string.Equals(unit.BlueprintVersion, domain.BlueprintVersion, StringComparison.Ordinal))
            {
                throw Invalid($"Unit '{unit.Id}' does not match its domain.");
            }

            var certification = Required(graph.Certifications, unit.CertificationId, "certification");
            EnsureLifecycleCompatible(unit.Id, unit.Lifecycle.Status, certification.Status);

            foreach (var lessonId in unit.LessonIds)
            {
                var lesson = Required(graph.Lessons, lessonId, "lesson");
                if (!string.Equals(lesson.UnitId, unit.Id, StringComparison.Ordinal))
                {
                    throw Invalid($"Unit '{unit.Id}' references lesson '{lesson.Id}' owned by another unit.");
                }
            }
        }

        foreach (var lesson in graph.Lessons.Values)
        {
            var unit = Required(graph.Units, lesson.UnitId, "unit");
            if (!string.Equals(lesson.CertificationId, unit.CertificationId, StringComparison.Ordinal)
                || !string.Equals(lesson.BlueprintVersion, unit.BlueprintVersion, StringComparison.Ordinal))
            {
                throw Invalid($"Lesson '{lesson.Id}' does not match its unit.");
            }

            var certification = Required(
                graph.Certifications,
                lesson.CertificationId,
                "certification");
            EnsureLifecycleCompatible(lesson.Id, lesson.Lifecycle.Status, certification.Status);

            var lessonQuestionIds = new HashSet<string>(StringComparer.Ordinal);
            foreach (var block in lesson.Blocks)
            {
                var concept = Required(graph.Concepts, block.ConceptId, "concept");
                if (!string.Equals(concept.DomainId, unit.DomainId, StringComparison.Ordinal))
                {
                    throw Invalid($"Lesson block '{block.Id}' references a concept from another domain.");
                }

                if (IsDistributableStatus(lesson.Lifecycle.Status)
                    && !IsDistributableStatus(concept.Lifecycle.Status))
                {
                    throw Invalid(
                        $"Distributable lesson '{lesson.Id}' references non-distributable concept '{concept.Id}'.");
                }

                if (block.QuestionId is not null)
                {
                    if (!lessonQuestionIds.Add(block.QuestionId))
                    {
                        throw Invalid(
                            $"Lesson '{lesson.Id}' references question '{block.QuestionId}' more than once.");
                    }

                    var question = Required(graph.Questions, block.QuestionId, "question");
                    if (!string.Equals(question.ConceptId, block.ConceptId, StringComparison.Ordinal)
                        || !string.Equals(question.DomainId, unit.DomainId, StringComparison.Ordinal))
                    {
                        throw Invalid($"Lesson check '{block.Id}' references an incompatible question.");
                    }
                }
            }
        }

        _ = new RuntimeContentProjector().Project(graph);
    }

    private static void ValidateCoverage(
        CanonicalContentGraph graph,
        IReadOnlyDictionary<string, JsonElement> publicResources)
    {
        var coveredQuestionIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var coverage in publicResources
                     .Where(entry => ResourceTypeFromPath(entry.Key) == "coverageMatrix")
                     .Select(entry => entry.Value))
        {
            var certificationId = coverage.GetProperty("certification").GetString()
                ?? throw Invalid("Coverage matrix certification is missing.");
            var certification = Required(graph.Certifications, certificationId, "certification");
            var blueprintVersion = coverage.GetProperty("blueprintVersion").GetString();
            if (!string.Equals(
                    blueprintVersion,
                    certification.BlueprintVersion,
                    StringComparison.Ordinal))
            {
                throw Invalid(
                    $"Coverage matrix '{certificationId}' does not match the catalog blueprint.");
            }

            foreach (var objective in coverage.GetProperty("objectives").EnumerateArray())
            {
                var objectiveId = objective.GetProperty("objective").GetString()
                    ?? throw Invalid($"Coverage matrix '{certificationId}' has an objective without id.");
                if (certification.Objectives.All(candidate =>
                        !string.Equals(candidate.Id, objectiveId, StringComparison.Ordinal)))
                {
                    throw Invalid(
                        $"Coverage matrix '{certificationId}' references unknown objective '{objectiveId}'.");
                }

                foreach (var questionIdElement in objective.GetProperty("questionIds").EnumerateArray())
                {
                    var questionId = questionIdElement.GetString()
                        ?? throw Invalid("Coverage question id is null.");
                    var question = Required(graph.Questions, questionId, "question");
                    if (!string.Equals(question.CertificationId, certificationId, StringComparison.Ordinal)
                        || !string.Equals(question.ObjectiveId, objectiveId, StringComparison.Ordinal))
                    {
                        throw Invalid(
                            $"Coverage question '{questionId}' does not match '{certificationId}/{objectiveId}'.");
                    }

                    if (!coveredQuestionIds.Add(questionId))
                    {
                        throw Invalid($"Question '{questionId}' appears more than once in coverage matrices.");
                    }
                }
            }
        }

        if (!coveredQuestionIds.SetEquals(graph.Questions.Keys))
        {
            var missing = graph.Questions.Keys.Except(coveredQuestionIds, StringComparer.Ordinal);
            throw Invalid(
                $"Coverage matrices do not cover every runtime question; missing=[{string.Join(",", missing)}].");
        }
    }

    private static void EnsureLifecycleCompatible(
        string resourceId,
        string resourceStatus,
        string certificationStatus)
    {
        var distributable = IsDistributableStatus(resourceStatus);
        var certificationUnavailable = certificationStatus is "retired" or "replaced";
        if (distributable && certificationUnavailable)
        {
            throw Invalid(
                $"Runtime resource '{resourceId}' is distributable under '{certificationStatus}' certification.");
        }
    }

    private static bool IsDistributableStatus(string status)
        => status is "active" or "retiring";

    private static void EnsureUnique(IEnumerable<string> values, string description)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var value in values)
        {
            if (!seen.Add(value))
            {
                throw Invalid($"Duplicate {description} '{value}'.");
            }
        }
    }

    private static void EnsureExactReferenceClosure(
        IEnumerable<string> referencedIds,
        IEnumerable<string> declaredIds,
        string resourceType)
    {
        var references = referencedIds.ToArray();
        EnsureUnique(references, $"referenced {resourceType} id");
        var referenced = references.ToHashSet(StringComparer.Ordinal);
        var declared = declaredIds.ToHashSet(StringComparer.Ordinal);
        if (!referenced.SetEquals(declared))
        {
            var orphans = declared.Except(referenced, StringComparer.Ordinal);
            throw Invalid(
                $"Canonical {resourceType} resources are not exactly reachable; "
                + $"orphans=[{string.Join(",", orphans)}].");
        }
    }

    private static CanonicalTrackResource ParseTrack(JsonElement value)
    {
        var resource = Deserialize<TrackContract>(value, "track");
        return new CanonicalTrackResource(
            resource.Id,
            resource.LegacyId,
            resource.CertificationId,
            resource.BlueprintVersion,
            resource.Mode,
            resource.Summary,
            resource.DomainIds,
            resource.UnitIds,
            ToLifecycle(resource.Lifecycle));
    }

    private static CanonicalDomainResource ParseDomain(JsonElement value)
    {
        var resource = Deserialize<DomainContract>(value, "domain");
        return new CanonicalDomainResource(
            resource.Id,
            resource.LegacyId,
            resource.CertificationId,
            resource.BlueprintVersion,
            resource.ObjectiveId,
            ToLifecycle(resource.Lifecycle));
    }

    private static CanonicalUnitResource ParseUnit(JsonElement value)
    {
        var resource = Deserialize<UnitContract>(value, "unit");
        return new CanonicalUnitResource(
            resource.Id,
            resource.LegacyId,
            resource.CertificationId,
            resource.BlueprintVersion,
            resource.DomainId,
            resource.Title,
            resource.LessonIds,
            ToLifecycle(resource.Lifecycle));
    }

    private static CanonicalLessonResource ParseLesson(JsonElement value)
    {
        var resource = Deserialize<LessonContract>(value, "lesson");
        return new CanonicalLessonResource(
            resource.Id,
            resource.LegacyId,
            resource.CertificationId,
            resource.BlueprintVersion,
            resource.UnitId,
            resource.Title,
            resource.EstimatedMinutes,
            resource.Blocks.Select(block => new CanonicalLessonBlock(
                block.Id,
                block.Type,
                block.ConceptId,
                block.Title,
                block.Body,
                block.Code,
                block.Language,
                block.QuestionId)).ToArray(),
            ToLifecycle(resource.Lifecycle));
    }

    private static CanonicalConceptResource ParseConcept(JsonElement value)
    {
        var resource = Deserialize<ConceptContract>(value, "concept");
        return new CanonicalConceptResource(
            resource.Id,
            resource.LegacyId,
            resource.CertificationId,
            resource.BlueprintVersion,
            resource.DomainId,
            resource.Title,
            ToLifecycle(resource.Lifecycle));
    }

    private static CanonicalQuestion ParseQuestion(JsonElement value)
    {
        var schemaVersion = value.GetProperty("schemaVersion").GetString();
        if (!string.Equals(schemaVersion, "v4", StringComparison.Ordinal))
        {
            throw Invalid($"Runtime release contains non-v4 public question '{value.GetProperty("id")}'.");
        }

        var resource = Deserialize<QuestionContract>(value, "question");
        return new CanonicalQuestion(
            resource.Id,
            resource.LegacyId,
            resource.Metadata.Certification,
            resource.Metadata.BlueprintVersion,
            resource.Metadata.Objective,
            resource.Metadata.DomainId,
            resource.Metadata.ConceptId,
            resource.ItemType,
            resource.Difficulty,
            resource.Prompt,
            resource.Options);
    }

    private static CanonicalSolution ParseSolution(JsonElement value)
    {
        var schemaVersion = value.GetProperty("schemaVersion").GetString();
        if (!string.Equals(schemaVersion, "v4", StringComparison.Ordinal))
        {
            throw Invalid($"Runtime release contains non-v4 private solution '{value.GetProperty("id")}'.");
        }

        var resource = Deserialize<SolutionContract>(value, "solution");
        return new CanonicalSolution(resource.Id, resource.CorrectOptionIds, resource.Rationale);
    }

    private static CanonicalContentLifecycle ToLifecycle(LifecycleContract lifecycle)
        => new(lifecycle.Status, lifecycle.RetiredOn, lifecycle.ReplacedBy);

    private void ValidateSchema(string schemaFileName, JsonElement value)
    {
        try
        {
            schemaValidator.Validate(schemaFileName, value);
        }
        catch (ContentReleaseValidationException)
        {
            throw;
        }
        catch (Exception exception)
        {
            throw Invalid($"Schema validation failed for '{schemaFileName}'.", exception);
        }
    }

    private void ValidatePayloadSchema(string resourceType, JsonElement value)
    {
        var schema = resourceType switch
        {
            "certificationCatalog" => "certification-catalog.schema.json",
            "coverageMatrix" => "coverage-matrix.schema.json",
            "question" => "question.schema.json",
            "solution" => "solution.schema.json",
            "track" or "domain" or "unit" or "lesson" or "concept" => "runtime-resource.schema.json",
            _ => throw Invalid($"Unsupported package resourceType '{resourceType}'."),
        };
        ValidateSchema(schema, value);
    }

    private static void VerifyReleaseDescriptor(
        ContentReleaseDescriptor descriptor,
        string requestedReleaseId,
        JsonElement value)
    {
        if (descriptor.Schema != ContentReleaseContracts.ReleaseV1
            || descriptor.Algorithm != "sha256"
            || descriptor.Canonicalization != "json-sorted-keys-compact-utf8")
        {
            throw Invalid("Release descriptor constants do not match certigo.content.release/v1.");
        }

        EnsureDigestId(descriptor.PublicManifestId, nameof(descriptor.PublicManifestId));
        EnsureDigestId(descriptor.PrivateManifestId, nameof(descriptor.PrivateManifestId));
        EnsureDigestId(descriptor.ReleaseId, nameof(descriptor.ReleaseId));
        var expected = $"sha256:{Sha256Hex(Canonicalize(value, "releaseId"))}";
        if (!string.Equals(descriptor.ReleaseId, expected, StringComparison.Ordinal)
            || !string.Equals(requestedReleaseId, expected, StringComparison.Ordinal))
        {
            throw Invalid($"Release id is '{descriptor.ReleaseId}'; expected '{expected}'.");
        }
    }

    private static void VerifyManifestIdentity(ContentPackageManifest manifest, JsonElement value)
    {
        if (manifest.Schema is not (
                ContentReleaseContracts.PackageManifestV1
                or ContentReleaseContracts.PackageManifestV2
                or ContentReleaseContracts.PackageManifestV3)
            || manifest.Algorithm != "sha256"
            || manifest.Serialization != "json-sorted-keys-compact-utf8-lf")
        {
            throw Invalid("Package manifest constants are unsupported.");
        }

        var digest = Sha256Hex(Canonicalize(value, "manifestId", "rootHash"));
        if (!string.Equals(manifest.ManifestId, $"sha256:{digest}", StringComparison.Ordinal)
            || !string.Equals(manifest.RootHash, digest, StringComparison.Ordinal))
        {
            throw Invalid($"Package manifest '{manifest.ManifestId}' has an invalid canonical digest.");
        }
    }

    private static void VerifyArtifact(ContentPackageManifest manifest, ContentArtifact artifact)
    {
        var expectedChannel = artifact == ContentArtifact.Public ? "public" : "answerKey";
        var expectedArtifact = artifact == ContentArtifact.Public ? "public" : "private";
        if (!string.Equals(manifest.Channel, expectedChannel, StringComparison.Ordinal)
            || !string.Equals(manifest.Artifact, expectedArtifact, StringComparison.Ordinal))
        {
            throw Invalid(
                $"{artifact} manifest declares channel='{manifest.Channel}', artifact='{manifest.Artifact}'.");
        }
    }

    private static void VerifyResourceIdentity(
        ContentPackageFile file,
        string resourceType,
        JsonElement value)
    {
        string actualId;
        if (resourceType == "certificationCatalog")
        {
            actualId = "certification-catalog";
        }
        else if (resourceType == "coverageMatrix")
        {
            actualId = value.GetProperty("certification").GetString() ?? string.Empty;
        }
        else
        {
            actualId = value.GetProperty("id").GetString() ?? string.Empty;
        }

        if (!string.Equals(file.Id, actualId, StringComparison.Ordinal))
        {
            throw Invalid(
                $"Manifest id '{file.Id}' does not match payload identity '{actualId}' for '{file.Path}'.");
        }
    }

    private static string ResolveResourceType(
        string manifestSchema,
        ContentPackageFile file,
        ContentArtifact artifact)
    {
        if (manifestSchema != ContentReleaseContracts.PackageManifestV1
            && !string.IsNullOrWhiteSpace(file.ResourceType))
        {
            return file.ResourceType;
        }

        return artifact == ContentArtifact.Private
            ? "solution"
            : ResourceTypeFromPath(file.Path)
              ?? throw Invalid($"Cannot infer resource type for '{file.Path}'.");
    }

    private static string? ResourceTypeFromPath(string path)
    {
        if (path.StartsWith("questions/", StringComparison.Ordinal))
            return "question";
        if (path.StartsWith("solutions/", StringComparison.Ordinal))
            return "solution";
        if (path == "catalog/certifications.json")
            return "certificationCatalog";
        if (path.StartsWith("coverage/", StringComparison.Ordinal))
            return "coverageMatrix";
        if (path.StartsWith("runtime/tracks/", StringComparison.Ordinal))
            return "track";
        if (path.StartsWith("runtime/domains/", StringComparison.Ordinal))
            return "domain";
        if (path.StartsWith("runtime/units/", StringComparison.Ordinal))
            return "unit";
        if (path.StartsWith("runtime/lessons/", StringComparison.Ordinal))
            return "lesson";
        if (path.StartsWith("runtime/concepts/", StringComparison.Ordinal))
            return "concept";
        return null;
    }

    private static void EnsurePublic(JsonElement value, string location)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in value.EnumerateObject())
                {
                    if (PublicForbiddenKeys.Contains(property.Name))
                    {
                        throw Invalid($"Public content contains forbidden key '{location}.{property.Name}'.");
                    }

                    EnsurePublic(property.Value, $"{location}.{property.Name}");
                }

                break;
            case JsonValueKind.Array:
                var index = 0;
                foreach (var item in value.EnumerateArray())
                {
                    EnsurePublic(item, $"{location}[{index++}]");
                }

                break;
        }
    }

    private static byte[] Canonicalize(JsonElement value, params string[] excludedRootProperties)
    {
        var buffer = new ArrayBufferWriter<byte>();
        using var writer = new Utf8JsonWriter(buffer, new JsonWriterOptions
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            Indented = false,
            SkipValidation = false,
        });
        WriteCanonical(
            writer,
            value,
            excludedRootProperties.ToHashSet(StringComparer.Ordinal),
            isRoot: true);
        writer.Flush();
        return buffer.WrittenSpan.ToArray();
    }

    private static void WriteCanonical(
        Utf8JsonWriter writer,
        JsonElement value,
        IReadOnlySet<string> excludedRootProperties,
        bool isRoot)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (var property in value.EnumerateObject()
                             .Where(property => !isRoot || !excludedRootProperties.Contains(property.Name))
                             .OrderBy(property => property.Name, StringComparer.Ordinal))
                {
                    writer.WritePropertyName(property.Name);
                    WriteCanonical(writer, property.Value, excludedRootProperties, isRoot: false);
                }

                writer.WriteEndObject();
                break;
            case JsonValueKind.Array:
                writer.WriteStartArray();
                foreach (var item in value.EnumerateArray())
                {
                    WriteCanonical(writer, item, excludedRootProperties, isRoot: false);
                }

                writer.WriteEndArray();
                break;
            case JsonValueKind.String:
                writer.WriteStringValue(value.GetString());
                break;
            case JsonValueKind.Number:
                writer.WriteRawValue(value.GetRawText(), skipInputValidation: false);
                break;
            case JsonValueKind.True:
                writer.WriteBooleanValue(true);
                break;
            case JsonValueKind.False:
                writer.WriteBooleanValue(false);
                break;
            case JsonValueKind.Null:
                writer.WriteNullValue();
                break;
            default:
                throw Invalid($"Unsupported JSON token '{value.ValueKind}' in canonical value.");
        }
    }

    private long AddAndCheckSize(long currentTotalBytes, ContentBlobObject blob)
    {
        if (blob.Content.Length > limits.MaxFileBytes)
        {
            throw Invalid(
                $"Blob '{blob.Path}' has {blob.Content.Length} bytes; limit is {limits.MaxFileBytes}.");
        }

        var total = checked(currentTotalBytes + blob.Content.Length);
        if (total > limits.MaxReleaseBytes)
        {
            throw Invalid(
                $"Release exceeds the configured {limits.MaxReleaseBytes}-byte limit.");
        }

        return total;
    }

    private static JsonDocument ParseJson(ContentBlobObject blob)
        => ParseJson(blob.Content.Span, blob.Path);

    private static JsonDocument ParseJson(ReadOnlySpan<byte> bytes, string path)
    {
        try
        {
            return JsonDocument.Parse(bytes.ToArray(), new JsonDocumentOptions
            {
                AllowTrailingCommas = false,
                CommentHandling = JsonCommentHandling.Disallow,
                MaxDepth = 64,
            });
        }
        catch (JsonException exception)
        {
            throw Invalid($"Blob '{path}' is not valid JSON.", exception);
        }
    }

    private static T Deserialize<T>(JsonElement value, string path)
        where T : notnull
    {
        try
        {
            return value.Deserialize<T>(ContractJsonOptions)
                   ?? throw Invalid($"JSON resource '{path}' is empty.");
        }
        catch (JsonException exception)
        {
            throw Invalid($"JSON resource '{path}' does not match the typed contract.", exception);
        }
    }

    private static JsonSerializerOptions CreateContractJsonOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web)
        {
            PropertyNameCaseInsensitive = false,
            UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        };
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        return options;
    }

    private static void EnsureImmutable(ContentBlobObject blob)
    {
        if (!blob.IsImmutable || string.IsNullOrWhiteSpace(blob.VersionId))
        {
            throw Invalid($"Blob '{blob.Path}' is not an immutable, version-pinned object.");
        }
    }

    private static void EnsureSafeRelativePath(string path)
    {
        if (string.IsNullOrWhiteSpace(path)
            || path.StartsWith("/", StringComparison.Ordinal)
            || path.Contains('\\', StringComparison.Ordinal)
            || path.Split('/').Any(segment => segment is "" or "." or ".."))
        {
            throw Invalid($"Package path '{path}' is unsafe or non-canonical.");
        }
    }

    private static void EnsureDigestId(string value, string name)
    {
        if (!DigestIdRegex().IsMatch(value))
        {
            throw Invalid($"{name} '{value}' is not a sha256 content identity.");
        }
    }

    private static void EnsureHexDigest(string value, string name)
    {
        if (!HexDigestRegex().IsMatch(value))
        {
            throw Invalid($"{name} '{value}' is not a lowercase SHA-256 digest.");
        }
    }

    private static string Sha256Hex(ReadOnlySpan<byte> bytes)
        => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    private static ContentBlobVersion ToVersion(ContentBlobObject blob)
        => new(blob.Path, blob.VersionId, blob.ETag);

    private static void AddUnique<T>(
        IDictionary<string, T> values,
        T value,
        string resourceType)
        where T : notnull
    {
        var id = value switch
        {
            CanonicalTrackResource resource => resource.Id,
            CanonicalDomainResource resource => resource.Id,
            CanonicalUnitResource resource => resource.Id,
            CanonicalLessonResource resource => resource.Id,
            CanonicalConceptResource resource => resource.Id,
            CanonicalQuestion resource => resource.Id,
            CanonicalSolution resource => resource.Id,
            _ => throw new InvalidOperationException($"Unsupported canonical type '{typeof(T).Name}'."),
        };
        if (!values.TryAdd(id, value))
        {
            throw Invalid($"Duplicate canonical {resourceType} id '{id}'.");
        }
    }

    private static T Required<T>(
        IReadOnlyDictionary<string, T> values,
        string id,
        string resourceType)
        where T : notnull
        => values.TryGetValue(id, out var value)
            ? value
            : throw Invalid($"Canonical {resourceType} '{id}' was not found.");

    private static ContentReleaseValidationException Invalid(
        string message,
        Exception? innerException = null)
        => new(message, innerException);

    [GeneratedRegex("^sha256:[0-9a-f]{64}$", RegexOptions.CultureInvariant)]
    private static partial Regex DigestIdRegex();

    [GeneratedRegex("^[0-9a-f]{64}$", RegexOptions.CultureInvariant)]
    private static partial Regex HexDigestRegex();

    private sealed record PackageReadResult(
        ContentPackageManifest Manifest,
        IReadOnlyDictionary<string, JsonElement> Resources,
        long TotalBytes);

    private sealed record LifecycleContract(
        string Status,
        DateOnly? RetiredOn = null,
        string? ReplacedBy = null);

    private sealed record TrackContract(
        string Schema,
        string ResourceType,
        string Id,
        string? LegacyId,
        string CertificationId,
        string BlueprintVersion,
        string Mode,
        string Summary,
        IReadOnlyList<string> DomainIds,
        IReadOnlyList<string> UnitIds,
        LifecycleContract Lifecycle);

    private sealed record DomainContract(
        string Schema,
        string ResourceType,
        string Id,
        string? LegacyId,
        string CertificationId,
        string BlueprintVersion,
        string ObjectiveId,
        LifecycleContract Lifecycle);

    private sealed record UnitContract(
        string Schema,
        string ResourceType,
        string Id,
        string? LegacyId,
        string CertificationId,
        string BlueprintVersion,
        string DomainId,
        string Title,
        IReadOnlyList<string> LessonIds,
        LifecycleContract Lifecycle);

    private sealed record LessonContract(
        string Schema,
        string ResourceType,
        string Id,
        string? LegacyId,
        string CertificationId,
        string BlueprintVersion,
        string UnitId,
        string Title,
        int EstimatedMinutes,
        IReadOnlyList<BlockContract> Blocks,
        LifecycleContract Lifecycle);

    private sealed record BlockContract(
        string Id,
        string Type,
        string ConceptId,
        string? Title = null,
        string? Body = null,
        string? Code = null,
        string? Language = null,
        string? QuestionId = null);

    private sealed record ConceptContract(
        string Schema,
        string ResourceType,
        string Id,
        string? LegacyId,
        string CertificationId,
        string BlueprintVersion,
        string DomainId,
        string Title,
        LifecycleContract Lifecycle);

    private sealed record QuestionMetadataContract(
        string Provider,
        string Certification,
        string BlueprintVersion,
        string Objective,
        string DomainId,
        string ConceptId);

    private sealed record QuestionContract(
        string Id,
        string? LegacyId,
        string SchemaVersion,
        string Kind,
        QuestionMetadataContract Metadata,
        ItemType ItemType,
        int Difficulty,
        string Prompt,
        IReadOnlyList<CheckOption> Options);

    private sealed record SolutionContract(
        string Id,
        string SchemaVersion,
        string Kind,
        IReadOnlyList<string> CorrectOptionIds,
        string Rationale);
}
