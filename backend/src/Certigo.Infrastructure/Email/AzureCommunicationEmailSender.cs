using Azure;
using Microsoft.Extensions.Logging;
using Certigo.Application.Abstractions;
using AcsEmailAddress = Azure.Communication.Email.EmailAddress;
using AcsEmailClient = Azure.Communication.Email.EmailClient;
using AcsEmailContent = Azure.Communication.Email.EmailContent;
using AcsEmailMessage = Azure.Communication.Email.EmailMessage;
using AcsEmailRecipients = Azure.Communication.Email.EmailRecipients;

namespace Certigo.Infrastructure.Email;

/// Production <see cref="IEmailSender"/> backed by Azure Communication Services
/// Email. Wired in Program.cs only when the ACS settings are present; otherwise
/// the <see cref="LoggingEmailSender"/> no-op is used so the flow still works.
/// Requires a verified sender address (Azure-managed or custom domain) on the ACS
/// Email resource, and — when using managed identity instead of a connection
/// string — the "Communication and Email Service Owner" role on that resource.
public sealed class AzureCommunicationEmailSender(
    AcsEmailClient client,
    string senderAddress,
    ILogger<AzureCommunicationEmailSender> logger) : IEmailSender
{
    public async Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        var content = new AcsEmailContent(message.Subject)
        {
            PlainText = message.PlainTextBody,
            Html = message.HtmlBody,
        };
        var recipients = new AcsEmailRecipients(new[] { new AcsEmailAddress(message.ToEmail, message.ToName) });
        var acsMessage = new AcsEmailMessage(senderAddress, recipients, content);

        try
        {
            // Fire-and-forget at the API level (WaitUntil.Started): we don't block
            // the request on SMTP delivery; ACS handles retries/DLR asynchronously.
            await client.SendAsync(WaitUntil.Started, acsMessage, cancellationToken);
        }
        catch (RequestFailedException ex)
        {
            // Surface the provider fault for diagnostics, then rethrow so the
            // caller's best-effort guard can decide (registration stays non-blocking).
            logger.LogWarning(ex, "Azure Communication Services failed to send email to {Recipient}.", message.ToEmail);
            throw;
        }
    }
}
