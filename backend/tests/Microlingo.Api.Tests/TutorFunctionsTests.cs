using System.Collections.Generic;
using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class TutorFunctionsTests
{
    [Fact]
    public async Task ExplainAnswer_Returns200_AndForwardsBody_WhenAuthenticated()
    {
        var service = new FakeTutorService();
        var function = new TutorFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new TutorExplainRequest("track-1", "lesson-1", "item-1", new List<string> { "a" });
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/tutor/explain", body);

        var response = await function.ExplainAnswer(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.CallCount.Should().Be(1);
        service.LastRequest!.TrackId.Should().Be("track-1");
    }

    [Fact]
    public async Task ExplainAnswer_Throws_WhenUnauthenticated()
    {
        var service = new FakeTutorService();
        var function = new TutorFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/tutor/explain");

        var act = () => function.ExplainAnswer(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task ExplainAnswer_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeTutorService();
        var function = new TutorFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/tutor/explain");

        var act = () => function.ExplainAnswer(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.CallCount.Should().Be(0);
    }
}
