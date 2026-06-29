using System;
using System.Collections.Generic;
using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ExamFunctionsTests
{
    [Fact]
    public async Task GenerateMockExam_Returns200_AndForwardsBody_WhenAuthenticated()
    {
        var service = new FakeExamService();
        var function = new ExamFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new MockExamRequest("track-1", null);
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/exam/generate", body);

        var response = await function.GenerateMockExam(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.GenerateCallCount.Should().Be(1);
        service.LastGenerate!.TrackId.Should().Be("track-1");
    }

    [Fact]
    public async Task GenerateMockExam_Throws_WhenUnauthenticated()
    {
        var service = new FakeExamService();
        var function = new ExamFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/exam/generate");

        var act = () => function.GenerateMockExam(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.GenerateCallCount.Should().Be(0);
    }

    [Fact]
    public async Task GenerateMockExam_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeExamService();
        var function = new ExamFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/exam/generate");

        var act = () => function.GenerateMockExam(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.GenerateCallCount.Should().Be(0);
    }

    [Fact]
    public async Task SubmitMockExam_Returns200_AndForwardsBody_WhenAuthenticated()
    {
        var service = new FakeExamService();
        var function = new ExamFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new SubmitMockExamRequest("client-1", "track-1", "exam-1", DateTimeOffset.UnixEpoch, new List<AnswerDto>());
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/exam/submit", body);

        var response = await function.SubmitMockExam(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.SubmitCallCount.Should().Be(1);
        service.LastSubmit!.ClientAttemptId.Should().Be("client-1");
    }

    [Fact]
    public async Task SubmitMockExam_Throws_WhenUnauthenticated()
    {
        var service = new FakeExamService();
        var function = new ExamFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/exam/submit");

        var act = () => function.SubmitMockExam(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.SubmitCallCount.Should().Be(0);
    }

    [Fact]
    public async Task SubmitMockExam_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeExamService();
        var function = new ExamFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/exam/submit");

        var act = () => function.SubmitMockExam(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.SubmitCallCount.Should().Be(0);
    }
}
