using System.Security.Cryptography;
using System.Text;
using Microlingo.Application.Abstractions;

namespace Microlingo.Infrastructure.Identity;

/// PBKDF2 (SHA-256) password hashing using only the BCL — no third-party
/// dependency. The encoded form is <c>pbkdf2.{iterations}.{saltB64}.{keyB64}</c>
/// so the iteration count and salt travel with the hash and can be upgraded
/// later without a schema change. Verification is constant-time.
public sealed class Pbkdf2PasswordHasher : IPasswordHasher
{
    private const int SaltSize = 16;
    private const int KeySize = 32;
    private const int Iterations = 100_000;
    private static readonly HashAlgorithmName Algorithm = HashAlgorithmName.SHA256;

    public string Hash(string password)
    {
        ArgumentNullException.ThrowIfNull(password);
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var key = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, Algorithm, KeySize);
        return string.Join('.', "pbkdf2", Iterations, Convert.ToBase64String(salt), Convert.ToBase64String(key));
    }

    public bool Verify(string password, string hash)
    {
        if (string.IsNullOrEmpty(password) || string.IsNullOrEmpty(hash))
        {
            return false;
        }

        var parts = hash.Split('.');
        if (parts.Length != 4
            || !string.Equals(parts[0], "pbkdf2", StringComparison.Ordinal)
            || !int.TryParse(parts[1], out var iterations)
            || iterations <= 0)
        {
            return false;
        }

        byte[] salt;
        byte[] expectedKey;
        try
        {
            salt = Convert.FromBase64String(parts[2]);
            expectedKey = Convert.FromBase64String(parts[3]);
        }
        catch (FormatException)
        {
            return false;
        }

        var candidate = Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(password), salt, iterations, Algorithm, expectedKey.Length);
        return CryptographicOperations.FixedTimeEquals(candidate, expectedKey);
    }
}
