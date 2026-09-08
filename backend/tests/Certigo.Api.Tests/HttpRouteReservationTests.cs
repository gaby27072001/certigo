using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Certigo.Api.Functions;
using FluentAssertions;
using Microsoft.Azure.Functions.Worker;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// The Functions host refuses to register any HTTP function whose authored route
/// begins with a reserved segment. ScriptHost validates
/// <c>httpTrigger.Route</c> itself, so the <c>api</c> route prefix does not
/// protect us, and it throws rather than warning. The affected function is then
/// absent from the route table while ARM still reports it with a working-looking
/// invokeUrlTemplate, so every other signal stays green and the endpoint answers
/// 404 with an empty body. Only an assertion over the authored routes can catch
/// this before deployment.
/// </summary>
public sealed class HttpRouteReservationTests
{
    private static readonly string[] ReservedFirstSegments = ["admin", "runtime"];

    [Fact]
    public void No_http_route_begins_with_a_host_reserved_segment()
    {
        var routes = DeclaredHttpRoutes();

        // Negative control: if reflection stops finding routes this test would
        // pass vacuously, which is the failure mode it exists to prevent.
        routes.Should().NotBeEmpty("the scan must observe the API's HTTP routes for this assertion to mean anything");

        foreach (var (functionName, route) in routes)
        {
            var firstSegment = route.Trim('/').Split('/').First();

            ReservedFirstSegments.Should().NotContain(
                candidate => string.Equals(candidate, firstSegment, System.StringComparison.OrdinalIgnoreCase),
                $"function '{functionName}' declares route '{route}', and the Functions host refuses to "
                + "register routes beginning with a reserved segment, leaving the endpoint unreachable");
        }
    }

    private static IReadOnlyList<(string FunctionName, string Route)> DeclaredHttpRoutes()
    {
        var results = new List<(string, string)>();

        foreach (var type in typeof(ContentReleaseFunctions).Assembly.GetTypes())
        {
            var methods = type.GetMethods(
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly);

            foreach (var method in methods)
            {
                var function = method.GetCustomAttribute<FunctionAttribute>();
                if (function is null)
                {
                    continue;
                }

                foreach (var parameter in method.GetParameters())
                {
                    if (parameter.GetCustomAttribute<HttpTriggerAttribute>() is { Route: { Length: > 0 } route })
                    {
                        results.Add((function.Name, route));
                    }
                }
            }
        }

        return results;
    }
}
