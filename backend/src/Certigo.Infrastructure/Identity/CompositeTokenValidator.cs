using Certigo.Application.Abstractions;
using AppTokenValidationResult = Certigo.Application.Abstractions.TokenValidationResult;

namespace Certigo.Infrastructure.Identity;

/// Tries a chain of token validators in order and returns the first success.
/// Ordering matters: the local email/password validator is tried first, then the
/// Entra when configured, then the optional permissive Dev validator on explicitly
/// enabled development hosts. The Dev validator accepts ANY token, so it must always come last.
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

public sealed class ReauthenticationProofValidator(ITokenValidator validator)
    : IReauthenticationProofValidator
{
    public Task<AppTokenValidationResult> TryValidateAsync(
        string token,
        CancellationToken cancellationToken = default)
        => validator.TryValidateAsync(token, cancellationToken);
}
