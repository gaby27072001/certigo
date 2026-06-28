using System.Text.Json;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Exam;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Integrity;
using Microlingo.Domain.Notifications;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Readiness;
using Microlingo.Domain.Recommendation;
using Microlingo.Domain.Social;
using Microlingo.Domain.Tutor;

namespace Microlingo.Application.Services;

public interface ITutorService
{
    Task<TutorExplanationDto> ExplainAsync(TutorExplainRequest request, CancellationToken cancellationToken = default);
}

/// The premium AI tutor — a continuously learning agent. It grounds every
/// explanation in the official lesson + answer key, personalises it from the
/// learner's own history (recurring struggles, signature misconceptions, comeback
/// wins), optionally upgrades the prose via a guardrailed LLM, then *learns* from
/// the interaction by folding it back into the per-user model. Works for free and
/// offline (grounded composer) when no LLM provider is configured.
public sealed class TutorService(
    IUserContext userContext,
    IClock clock,
    IContentRepository content,
    ILearnerModelRepository learnerModels,
    ITutorCompletion completion,
    IEventRepository events) : ITutorService
{
    public async Task<TutorExplanationDto> ExplainAsync(TutorExplainRequest request, CancellationToken cancellationToken = default)
    {
        var track = await content.GetTrackAsync(request.TrackId, cancellationToken)
            ?? throw new InvalidOperationException($"Track '{request.TrackId}' was not found.");
        var lesson = await content.GetLessonAsync(request.TrackId, request.LessonId, cancellationToken)
            ?? throw new InvalidOperationException($"Lesson '{request.LessonId}' was not found.");
        var answerKey = await content.GetAnswerKeyAsync(request.TrackId, request.LessonId, cancellationToken)
            ?? throw new InvalidOperationException($"Answer key for lesson '{request.LessonId}' was not found.");

        var keyItem = answerKey.Items.FirstOrDefault(i =>
            string.Equals(i.ItemId, request.ItemId, StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException($"Item '{request.ItemId}' was not found in lesson '{request.LessonId}'.");

        var now = clock.UtcNow;
        var selected = request.Selected ?? new List<string>();

        // Personalise on the learner's history BEFORE this answer.
        var record = await learnerModels.GetAsync(userContext.UserId, request.TrackId, cancellationToken);
        var map = LearnerModelMap.ToMap(record);
        map.TryGetValue(keyItem.ConceptId, out var priorStat);

        var ctx = TutorContextFactory.Create(track, lesson, keyItem, selected, priorStat);
        var grounded = TutorComposer.Compose(ctx);
        var explanation = await UpgradeAsync(ctx, grounded, cancellationToken);

        // Learn from this interaction so the next explanation is more personal.
        var chosenWrong = ctx.IsCorrect ? null : selected.FirstOrDefault();
        map[keyItem.ConceptId] = LearnerModel.Observe(priorStat, keyItem.ConceptId, ctx.IsCorrect, chosenWrong, now);
        await learnerModels.UpsertAsync(
            LearnerModelMap.ToRecord(userContext.UserId, request.TrackId, map, now), cancellationToken);

        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "tutor.explained",
            now,
            new TutorEventPayload(request.TrackId, request.LessonId, keyItem.ItemId, keyItem.ConceptId, ctx.IsCorrect, explanation.Source)),
            cancellationToken);

        return ToDto(ctx, explanation);
    }

    // Attempts an LLM upgrade, but only adopts it if it survives the guardrails
    // (grounding, length, exam-integrity). A controlled provider outage falls
    // back to the grounded explanation, which is always safe; unexpected bugs
    // still surface. Empty replies, malformed JSON, or guardrail violations also
    // fall back to the grounded path. The recommendation stays grounded
    // regardless of source.
    private async Task<TutorExplanation> UpgradeAsync(
        TutorContext ctx,
        TutorExplanation grounded,
        CancellationToken cancellationToken)
    {
        string? raw;
        try
        {
            raw = await completion.CompleteAsync(
                TutorPromptBuilder.System(), TutorPromptBuilder.User(ctx), cancellationToken);
        }
        catch (TutorCompletionUnavailableException)
        {
            return grounded;
        }

        if (string.IsNullOrWhiteSpace(raw))
        {
            return grounded;
        }

        var candidate = TutorPayloadParser.TryParse(raw!, grounded.Recommendation);
        if (candidate is null)
        {
            return grounded;
        }

        var verdict = TutorGuardrails.Validate(candidate, ctx);
        return verdict.Ok ? candidate : grounded;
    }

    private static TutorExplanationDto ToDto(TutorContext ctx, TutorExplanation e)
    {
        var learner = ctx.Learner;
        var personalization = new TutorPersonalizationDto(
            learner.Attempts,
            learner.Errors,
            (int)Math.Round(learner.Accuracy * 100),
            learner.RecurringStruggle,
            learner.MasteredBefore,
            learner.Trend.ToString().ToLowerInvariant(),
            learner.TopConfusedOptionLabel);

        return new TutorExplanationDto(
            ctx.ItemId,
            ctx.ConceptId,
            ctx.IsCorrect,
            e.Headline,
            e.Points,
            e.Encouragement,
            e.Recommendation,
            e.CitedConceptIds,
            e.Source,
            personalization);
    }
}

internal sealed record TutorEventPayload(
    string TrackId,
    string LessonId,
    string ItemId,
    string ConceptId,
    bool Correct,
    string Source);

/// Parses an LLM reply into a tutor explanation. Tolerant of prose around the
/// JSON object (extracts the outermost braces); returns null on anything it can't
/// confidently read, so the caller falls back to the grounded explanation. The
/// recommendation is always taken from the grounded composer, never the model.
internal static class TutorPayloadParser
{
    public static TutorExplanation? TryParse(string raw, string groundedRecommendation)
    {
        var json = ExtractJsonObject(raw);
        if (json is null)
        {
            return null;
        }

        try
        {
            using var document = JsonDocument.Parse(json);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object)
            {
                return null;
            }

            var headline = GetString(root, "headline");
            var encouragement = GetString(root, "encouragement") ?? string.Empty;
            var points = GetStringArray(root, "points");
            var cited = GetStringArray(root, "citedConceptIds");

            if (string.IsNullOrWhiteSpace(headline) || points.Count == 0)
            {
                return null;
            }

            return new TutorExplanation(headline!, points, encouragement, cited, groundedRecommendation, "ai");
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static string? ExtractJsonObject(string raw)
    {
        var start = raw.IndexOf('{');
        var end = raw.LastIndexOf('}');
        if (start < 0 || end <= start)
        {
            return null;
        }

        return raw.Substring(start, end - start + 1);
    }

    private static string? GetString(JsonElement root, string name)
        => root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static IReadOnlyList<string> GetStringArray(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<string>();
        }

        var list = new List<string>();
        foreach (var element in value.EnumerateArray())
        {
            if (element.ValueKind == JsonValueKind.String)
            {
                var text = element.GetString();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    list.Add(text!);
                }
            }
        }

        return list;
    }
}
