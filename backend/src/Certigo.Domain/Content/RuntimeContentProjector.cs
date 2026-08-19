namespace Certigo.Domain.Content;

public sealed class RuntimeContentProjector
{
    public RuntimeContentProjection Project(CanonicalContentGraph graph)
    {
        var tracks = new List<ProjectedTrackDocument>();
        var lessons = new List<ProjectedLessonDocument>();
        var answerKeys = new List<ProjectedAnswerKeyDocument>();

        foreach (var track in graph.Tracks.Values.OrderBy(value => value.Id, StringComparer.Ordinal))
        {
            var certification = Required(graph.Certifications, track.CertificationId, "certification");
            if (string.Equals(track.Mode, "guided", StringComparison.Ordinal))
            {
                ProjectGuidedTrack(graph, track, certification, tracks, lessons, answerKeys);
            }
            else if (string.Equals(track.Mode, "questionBank", StringComparison.Ordinal))
            {
                ProjectQuestionBankTrack(graph, track, certification, tracks, lessons, answerKeys);
            }
            else
            {
                throw new ContentProjectionException(
                    $"Track '{track.Id}' has unsupported mode '{track.Mode}'.");
            }
        }

        return new RuntimeContentProjection(tracks, lessons, answerKeys);
    }

    private static void ProjectGuidedTrack(
        CanonicalContentGraph graph,
        CanonicalTrackResource track,
        CanonicalCertification certification,
        ICollection<ProjectedTrackDocument> projectedTracks,
        ICollection<ProjectedLessonDocument> projectedLessons,
        ICollection<ProjectedAnswerKeyDocument> projectedAnswerKeys)
    {
        var trackId = RuntimeId(track.Id, track.LegacyId);
        var domains = track.DomainIds
            .Select(domainId => ProjectDomain(graph, domainId))
            .ToArray();
        var units = new List<TrackUnit>();

        foreach (var unitId in track.UnitIds)
        {
            var unit = Required(graph.Units, unitId, "unit");
            var domain = Required(graph.Domains, unit.DomainId, "domain");
            var lessonIds = new List<string>();

            foreach (var lessonId in unit.LessonIds)
            {
                var lesson = Required(graph.Lessons, lessonId, "lesson");
                var runtimeLessonId = RuntimeId(lesson.Id, lesson.LegacyId);
                var blocks = new List<LessonBlock>();
                var answers = new List<AnswerKeyItem>();

                foreach (var block in lesson.Blocks)
                {
                    var projected = ProjectBlock(graph, block);
                    blocks.Add(projected.Block);
                    if (projected.Answer is not null)
                    {
                        answers.Add(projected.Answer);
                    }
                }

                lessonIds.Add(runtimeLessonId);
                projectedLessons.Add(new ProjectedLessonDocument(
                    lesson.Id,
                    lesson.LegacyId,
                    runtimeLessonId,
                    lesson.Lifecycle.Status,
                    new Lesson(
                        runtimeLessonId,
                        trackId,
                        RuntimeId(unit.Id, unit.LegacyId),
                        RuntimeId(domain.Id, domain.LegacyId),
                        lesson.Title,
                        lesson.EstimatedMinutes,
                        blocks)));

                projectedAnswerKeys.Add(new ProjectedAnswerKeyDocument(
                    lesson.Id,
                    lesson.LegacyId,
                    runtimeLessonId,
                    lesson.Lifecycle.Status,
                    new LessonAnswerKey(
                        runtimeLessonId,
                        trackId,
                        RuntimeId(domain.Id, domain.LegacyId),
                        answers)));
            }

            units.Add(new TrackUnit(
                RuntimeId(unit.Id, unit.LegacyId),
                RuntimeId(domain.Id, domain.LegacyId),
                unit.Title,
                lessonIds));
        }

        projectedTracks.Add(new ProjectedTrackDocument(
            track.Id,
            track.LegacyId,
            trackId,
            track.Lifecycle.Status,
            new Track(
                trackId,
                certification.OfficialCode ?? certification.Slug.ToUpperInvariant(),
                certification.Title,
                track.Summary,
                domains,
                units,
                certification.Level,
                certification.Id)));
    }

    private static void ProjectQuestionBankTrack(
        CanonicalContentGraph graph,
        CanonicalTrackResource track,
        CanonicalCertification certification,
        ICollection<ProjectedTrackDocument> projectedTracks,
        ICollection<ProjectedLessonDocument> projectedLessons,
        ICollection<ProjectedAnswerKeyDocument> projectedAnswerKeys)
    {
        var trackId = RuntimeId(track.Id, track.LegacyId);
        var domains = new List<ExamDomain>();
        var units = new List<TrackUnit>();

        foreach (var domainId in track.DomainIds)
        {
            var domain = Required(graph.Domains, domainId, "domain");
            var objective = RequiredObjective(certification, domain.ObjectiveId);
            var runtimeDomainId = RuntimeId(domain.Id, domain.LegacyId);
            var runtimeUnitId = $"{trackId}.unit.{domain.ObjectiveId}";
            var runtimeLessonId = $"{trackId}.lesson.{domain.ObjectiveId}.practice";
            var questions = graph.Questions.Values
                .Where(question =>
                    string.Equals(question.CertificationId, track.CertificationId, StringComparison.Ordinal)
                    && string.Equals(question.DomainId, domain.Id, StringComparison.Ordinal))
                .OrderBy(question => question.Id, StringComparer.Ordinal)
                .ToArray();
            var blocks = new List<LessonBlock>();
            var answers = new List<AnswerKeyItem>();

            foreach (var question in questions)
            {
                var projected = ProjectQuestion(graph, question);
                blocks.Add(new LessonBlock(
                    "check",
                    projected.Check.ConceptId,
                    Check: projected.Check));
                answers.Add(projected.Answer);
            }

            projectedLessons.Add(new ProjectedLessonDocument(
                $"{track.Id}.lesson.{domain.ObjectiveId}.practice",
                null,
                runtimeLessonId,
                domain.Lifecycle.Status,
                new Lesson(
                    runtimeLessonId,
                    trackId,
                    runtimeUnitId,
                    runtimeDomainId,
                    $"{objective.Title} practice",
                    Math.Max(1, Math.Min(20, questions.Length * 2)),
                    blocks)));

            projectedAnswerKeys.Add(new ProjectedAnswerKeyDocument(
                $"{track.Id}.lesson.{domain.ObjectiveId}.practice",
                null,
                runtimeLessonId,
                domain.Lifecycle.Status,
                new LessonAnswerKey(
                    runtimeLessonId,
                    trackId,
                    runtimeDomainId,
                    answers)));

            domains.Add(new ExamDomain(
                runtimeDomainId,
                objective.Title,
                decimal.ToDouble(objective.WeightPercent / 100m)));
            units.Add(new TrackUnit(
                runtimeUnitId,
                runtimeDomainId,
                objective.Title,
                [runtimeLessonId]));
        }

        projectedTracks.Add(new ProjectedTrackDocument(
            track.Id,
            track.LegacyId,
            trackId,
            track.Lifecycle.Status,
            new Track(
                trackId,
                certification.OfficialCode ?? certification.Slug.ToUpperInvariant(),
                certification.Title,
                track.Summary,
                domains,
                units,
                certification.Level,
                certification.Id)));
    }

    private static ExamDomain ProjectDomain(CanonicalContentGraph graph, string domainId)
    {
        var domain = Required(graph.Domains, domainId, "domain");
        var certification = Required(graph.Certifications, domain.CertificationId, "certification");
        var objective = RequiredObjective(certification, domain.ObjectiveId);
        return new ExamDomain(
            RuntimeId(domain.Id, domain.LegacyId),
            objective.Title,
            decimal.ToDouble(objective.WeightPercent / 100m));
    }

    private static (LessonBlock Block, AnswerKeyItem? Answer) ProjectBlock(
        CanonicalContentGraph graph,
        CanonicalLessonBlock block)
    {
        var concept = Required(graph.Concepts, block.ConceptId, "concept");
        var runtimeConceptId = RuntimeId(concept.Id, concept.LegacyId);
        if (!string.Equals(block.Type, "check", StringComparison.Ordinal))
        {
            return (new LessonBlock(
                block.Type,
                runtimeConceptId,
                block.Title,
                block.Body,
                block.Code,
                block.Language), null);
        }

        if (string.IsNullOrWhiteSpace(block.QuestionId))
        {
            throw new ContentProjectionException($"Check block '{block.Id}' does not reference a question.");
        }

        var question = Required(graph.Questions, block.QuestionId, "question");
        var projected = ProjectQuestion(graph, question);
        if (!string.Equals(projected.Check.ConceptId, runtimeConceptId, StringComparison.Ordinal))
        {
            throw new ContentProjectionException(
                $"Check block '{block.Id}' and question '{question.Id}' reference different concepts.");
        }

        return (new LessonBlock(
            block.Type,
            runtimeConceptId,
            Check: projected.Check), projected.Answer);
    }

    private static (LessonCheck Check, AnswerKeyItem Answer) ProjectQuestion(
        CanonicalContentGraph graph,
        CanonicalQuestion question)
    {
        var concept = Required(graph.Concepts, question.ConceptId, "concept");
        var solution = Required(graph.Solutions, question.Id, "solution");
        var runtimeQuestionId = RuntimeId(question.Id, question.LegacyId);
        var runtimeConceptId = RuntimeId(concept.Id, concept.LegacyId);
        return (
            new LessonCheck(
                runtimeQuestionId,
                runtimeConceptId,
                question.ItemType,
                question.Prompt,
                question.Options),
            new AnswerKeyItem(
                runtimeQuestionId,
                runtimeConceptId,
                question.ItemType,
                question.Difficulty,
                solution.CorrectOptionIds,
                solution.Rationale));
    }

    private static CanonicalCertificationObjective RequiredObjective(
        CanonicalCertification certification,
        string objectiveId)
        => certification.Objectives.FirstOrDefault(objective =>
               string.Equals(objective.Id, objectiveId, StringComparison.Ordinal))
           ?? throw new ContentProjectionException(
               $"Certification '{certification.Id}' does not define objective '{objectiveId}'.");

    private static TValue Required<TValue>(
        IReadOnlyDictionary<string, TValue> values,
        string id,
        string resourceType)
        where TValue : notnull
        => values.TryGetValue(id, out var value)
            ? value
            : throw new ContentProjectionException(
                $"Canonical {resourceType} '{id}' was not found.");

    private static string RuntimeId(string canonicalId, string? legacyId)
        => string.IsNullOrWhiteSpace(legacyId) ? canonicalId : legacyId;
}
