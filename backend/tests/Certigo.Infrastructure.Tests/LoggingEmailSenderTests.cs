using Certigo.Application.Abstractions;
using Certigo.Infrastructure.Email;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class LoggingEmailSenderTests
{
    [Fact]
    public async Task No_op_logs_only_a_static_status_without_recipient_or_message_content()
    {
        var logger = new CapturingLogger<LoggingEmailSender>();
        var message = new EmailMessage(
            "person@example.test",
            "Private Name",
            "Reset your password",
            "<a href=\"https://example.test/reset?token=secret-token\">Reset</a>",
            "Reset at https://example.test/reset?token=secret-token");

        await new LoggingEmailSender(logger).SendAsync(message);

        var log = logger.Messages.Should().ContainSingle().Which;
        log.Should().Be("[email:noop] No email provider configured.");
        log.Should().NotContain("person@example.test");
        log.Should().NotContain("Private Name");
        log.Should().NotContain("Reset your password");
        log.Should().NotContain("secret-token");
    }
}
