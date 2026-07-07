namespace Certigo.Domain.Progress;

/// <summary>
/// Version of the Cortex adaptive-learning algorithm.
///
/// This mirrors the Dart client's <c>cortexAlgoVersion</c> constant and is the
/// backend half of the single-source-of-truth contract. It is pinned in the
/// shared golden vectors (<c>packages/cortex/test/golden/cortex_golden_vectors.json</c>)
/// and asserted by <c>CortexParityTests</c>, so any change to the scheduling,
/// mastery, weakness or readiness math must bump this value in lockstep with the
/// Dart side and refresh the golden expectations.
/// </summary>
public static class CortexAlgo
{
    public const string Version = "1.0.0";
}
