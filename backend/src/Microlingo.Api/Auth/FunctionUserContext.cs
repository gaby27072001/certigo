using System.Security.Claims;
using Microlingo.Application.Abstractions;

namespace Microlingo.Api.Auth;

public sealed class FunctionUserContext : IUserContext
{
    internal static readonly AsyncLocal<ClaimsPrincipal?> Current = new();

    public string UserId =>
        Current.Value?.FindFirst("oid")?.Value
        ?? Current.Value?.FindFirst(ClaimTypes.NameIdentifier)?.Value
        ?? Current.Value?.FindFirst("sub")?.Value
        ?? throw new UnauthorizedAccessException("No authenticated user is available.");

    public string DisplayName =>
        Current.Value?.Identity?.Name
        ?? Current.Value?.FindFirst("name")?.Value
        ?? Current.Value?.FindFirst("preferred_username")?.Value
        ?? "Microlingo learner";
}
