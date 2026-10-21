using Certigo.Application.Abstractions;
using Certigo.Infrastructure.Identity;

namespace Certigo.Api.Auth;

internal static class TokenValidatorConfiguration
{
    public static ITokenValidator Create(
        ITokenValidator local,
        string? authority,
        string? audience,
        bool useDev,
        Func<string, string, ITokenValidator> createEntra)
    {
        var validators = new List<ITokenValidator> { local };
        if (IsConfigured(authority) && IsConfigured(audience))
        {
            validators.Add(createEntra(authority!, audience!));
        }

        if (useDev)
        {
            validators.Add(new DevTokenValidator());
        }

        return new CompositeTokenValidator(validators);
    }

    private static bool IsConfigured(string? value)
        => !string.IsNullOrWhiteSpace(value)
           && !value.Contains("00000000-0000-0000-0000-000000000000", StringComparison.Ordinal);
}
