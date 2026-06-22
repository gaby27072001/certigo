using System.Text;

namespace Microlingo.Domain.Social;

// Deterministic, platform-independent codes for sharing and referrals. Uses a
// hand-rolled FNV-1a hash (not string.GetHashCode, which is randomized per
// process) so the same input always yields the same code on the server and in
// tests, and so a share link for a given day is stable.
public static class ShareCodec
{
    private const string Base32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    // An 8-character uppercase code a friend can type to credit the referrer.
    public static string ReferralCode(string userId)
        => Encode(Fnv1a("referral:" + userId), 8);

    // A 12-character lowercase token identifying a user's share card for one day,
    // suitable for a short share URL. Stable for the whole day.
    public static string DailyShareId(string userId, DateOnly date)
        => Encode(Fnv1a($"share:{userId}:{date.DayNumber}"), 12).ToLowerInvariant();

    private static ulong Fnv1a(string value)
    {
        const ulong offset = 14695981039346656037UL;
        const ulong prime = 1099511628211UL;
        var hash = offset;
        foreach (var b in Encoding.UTF8.GetBytes(value))
        {
            hash ^= b;
            hash *= prime;
        }

        return hash;
    }

    private static string Encode(ulong value, int length)
    {
        var chars = new char[length];
        for (var i = 0; i < length; i++)
        {
            chars[i] = Base32[(int)(value & 31)];
            value >>= 5;
        }

        return new string(chars);
    }
}
