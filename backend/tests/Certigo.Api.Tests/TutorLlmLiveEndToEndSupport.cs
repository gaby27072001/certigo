using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// Configuration for <see cref="TutorLlmLiveEndToEndTests"/>: which deployed API to hit
/// and which already-seeded content item to request an explanation for.
/// </summary>
public sealed record TutorLlmLiveConfig(
    Uri BaseUrl,
    string TrackId,
    string LessonId,
    string ItemId);

/// <summary>
/// Gate for the one real, over-the-network end-to-end test that proves the Azure
/// OpenAI / Microsoft Foundry tutor path is actually reachable and returning a real
/// (non-fallback) completion from a deployed environment — register → login → JWT →
/// <c>POST /api/tutor/explain</c> → 200 with <c>source == "ai"</c>.
///
/// Mirrors <see cref="CosmosEmulatorFixture"/> exactly: OPT-IN and gated behind
/// <see cref="EnableFlag"/>. With the flag unset — the default on a developer box or
/// CI agent, and in every environment today because <c>TUTOR_LLM_ENABLED=false</c>
/// everywhere (see docs/adr/ADR-O-01-ai-tutor-prod.md) — the gated test is reported as
/// *skipped* and this class never reads configuration or opens a connection, so the
/// build stays green and deterministic.
///
/// To run it for real, a human with actual access to the target environment must:
///   1. Confirm TUTOR_LLM_ENABLED=true is deployed there with a working model
///      deployment and the "Cognitive Services OpenAI User" role granted to the
///      Function App managed identity (see docs/deployment-runbook.md §T0.5
///      "Chemin 3" — this is NOT true in `dev` today; see infra/params/dev.bicepparam).
///   2. Set:
/// <code>
///   CERTIGO_TUTOR_LLM_LIVE_TESTS=1
///   CERTIGO_TUTOR_API_BASE_URL=https://&lt;function-app&gt;.azurewebsites.net
///   CERTIGO_TUTOR_TEST_TRACK_ID=&lt;a trackId that exists in that environment's seeded content&gt;
///   CERTIGO_TUTOR_TEST_LESSON_ID=&lt;a lessonId within that track&gt;
///   CERTIGO_TUTOR_TEST_ITEM_ID=&lt;a quiz itemId within that lesson&gt;
/// </code>
/// The track/lesson/item IDs are deliberately not hard-coded: seeded content differs
/// per environment and is authored in a separate repository (certigo-content), so
/// there is no ID this test project can safely assume exists.
/// </summary>
public static class TutorLlmLiveEnvironment
{
    public const string EnableFlag = "CERTIGO_TUTOR_LLM_LIVE_TESTS";

    private const string BaseUrlVariable = "CERTIGO_TUTOR_API_BASE_URL";
    private const string TrackIdVariable = "CERTIGO_TUTOR_TEST_TRACK_ID";
    private const string LessonIdVariable = "CERTIGO_TUTOR_TEST_LESSON_ID";
    private const string ItemIdVariable = "CERTIGO_TUTOR_TEST_ITEM_ID";

    /// <summary>True only when the opt-in flag is explicitly set to "1".</summary>
    public static bool Enabled =>
        string.Equals(Environment.GetEnvironmentVariable(EnableFlag), "1", StringComparison.Ordinal);

    /// <summary>
    /// Reads and validates the environment the live test needs. Only ever called from
    /// an executing (non-skipped) test body — never at discovery/initialise time — so a
    /// fully-skipped run never demands these variables be set.
    /// </summary>
    public static TutorLlmLiveConfig ReadRequiredConfig()
    {
        var baseUrlRaw = Environment.GetEnvironmentVariable(BaseUrlVariable);
        var trackId = Environment.GetEnvironmentVariable(TrackIdVariable);
        var lessonId = Environment.GetEnvironmentVariable(LessonIdVariable);
        var itemId = Environment.GetEnvironmentVariable(ItemIdVariable);

        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(baseUrlRaw)) missing.Add(BaseUrlVariable);
        if (string.IsNullOrWhiteSpace(trackId)) missing.Add(TrackIdVariable);
        if (string.IsNullOrWhiteSpace(lessonId)) missing.Add(LessonIdVariable);
        if (string.IsNullOrWhiteSpace(itemId)) missing.Add(ItemIdVariable);

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                $"{EnableFlag}=1 requires all of {BaseUrlVariable}, {TrackIdVariable}, " +
                $"{LessonIdVariable}, {ItemIdVariable} to be set. Missing: {string.Join(", ", missing)}.");
        }

        if (!Uri.TryCreate(baseUrlRaw, UriKind.Absolute, out var baseUrl))
        {
            throw new InvalidOperationException(
                $"{BaseUrlVariable} must be an absolute URL (e.g. https://<function-app>.azurewebsites.net), got '{baseUrlRaw}'.");
        }

        return new TutorLlmLiveConfig(baseUrl, trackId!, lessonId!, itemId!);
    }
}

/// <summary>
/// A <see cref="FactAttribute"/> that auto-skips unless the live tutor-LLM suite is
/// explicitly enabled (see <see cref="TutorLlmLiveEnvironment.EnableFlag"/>). The skip
/// decision is taken at construction/discovery time, so a gated-off run reports this
/// test as *skipped* rather than performing any network I/O.
/// </summary>
public sealed class TutorLlmLiveFactAttribute : FactAttribute
{
    public TutorLlmLiveFactAttribute()
    {
        if (!TutorLlmLiveEnvironment.Enabled)
        {
            Skip =
                $"Live tutor-LLM end-to-end test — set {TutorLlmLiveEnvironment.EnableFlag}=1 " +
                "with a deployed environment where TUTOR_LLM_ENABLED=true (RBAC + model deployment " +
                "confirmed) and the CERTIGO_TUTOR_* variables configured to execute. See " +
                "docs/deployment-runbook.md §T0.5 \"Chemin 3\".";
        }
    }
}
