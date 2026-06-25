using Microlingo.Application.Abstractions;
using AppTokenValidationResult = Microlingo.Application.Abstractions.TokenValidationResult;

namespace Microlingo.Infrastructure.Identity;

/// Tries a chain of token validators in order and returns the first success.
/// Ordering matters: the local email/password validator is tried first, then the
/// environment validator (Entra in production, or the permissive Dev validator in
/// development). The Dev validator accepts ANY token, so it must always come last.
public sealed class CompositeTokenValidator(IReadOnlyList<ITokenValidator> validators) : ITokenValidator
{
    public async Task<AppTokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default)
    {
        foreach (var validator in validators)
        {
            var result = await validator.TryValidateAsync(token, cancellationToken);
            if (result.Succeeded)
            {
                return result;
            }
        }

        return new AppTokenValidationResult(false, null, null);
    }
}
