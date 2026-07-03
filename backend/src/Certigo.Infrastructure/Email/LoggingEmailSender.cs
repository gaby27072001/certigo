using Microsoft.Extensions.Logging;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Email;

/// Safe default <see cref="IEmailSender"/> used whenever no real provider is
/// configured (local, CI, or a not-yet-provisioned environment). It does not send
/// anything — it logs the recipient, subject, and body at Information so the
/// register/verify flow still works end-to-end (the confirmation link is
/// recoverable from the logs) without blocking sign-up. Swapped for
/// <see cref="AzureCommunicationEmailSender"/> in Program.cs once ACS settings are
/// present.
public sealed class LoggingEmailSender(ILogger<LoggingEmailSender> logger) : IEmailSender
{
    public Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        // Information level intentionally omits the body: it carries the
        // verification link (email + raw token). The full body — including the
        // recoverable link for local/dev flows — is logged only at Debug.
        logger.LogInformation(
            "[email:noop] No email provider configured — would send to {Recipient}. Subject: {Subject}",
            message.ToEmail,
            message.Subject);
        logger.LogDebug("[email:noop] Body for {Recipient}: {Body}", message.ToEmail, message.PlainTextBody);
        return Task.CompletedTask;
    }
}
