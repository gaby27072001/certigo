using Microsoft.Extensions.Logging;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Email;

/// Safe default <see cref="IEmailSender"/> used whenever no real provider is
/// configured (local, CI, or a not-yet-provisioned environment). It does not send
/// anything — it logs only a static status marker, without exposing recipient
/// data or message content. Swapped for <see cref="AzureCommunicationEmailSender"/>
/// in Program.cs once ACS settings are present.
public sealed class LoggingEmailSender(ILogger<LoggingEmailSender> logger) : IEmailSender
{
    public Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        logger.LogInformation("[email:noop] No email provider configured.");
        return Task.CompletedTask;
    }
}
