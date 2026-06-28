using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Ai;

/// The default tutor-completion binding: no LLM provider. Returning null makes the
/// TutorService serve its deterministic, fully grounded explanation — so the AI
/// tutor works for free, offline, and in CI with zero Azure OpenAI dependency.
/// Swapping in a real Azure OpenAI / Foundry implementation later is a one-line
/// DI change; the guardrails already validate whatever an LLM returns.
public sealed class NullTutorCompletion : ITutorCompletion
{
    public Task<string?> CompleteAsync(string systemPrompt, string userPrompt, CancellationToken cancellationToken = default)
        => Task.FromResult<string?>(null);
}
