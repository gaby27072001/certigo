using System.Net;
using System.Net.Http.Headers;
using Azure.Core;
using Azure.Identity;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Identity;

public sealed class GraphExternalIdentityDeletion(
    HttpClient client,
    TokenCredential credential) : IExternalIdentityDeletion
{
    private static readonly TokenRequestContext GraphTokenRequest =
        new(["https://graph.microsoft.com/.default"]);

    public async Task DeleteAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var accessToken = await credential.GetTokenAsync(GraphTokenRequest, cancellationToken);
            var escapedSubject = Uri.EscapeDataString(subjectUserId);
            await RevokeSessionsAsync(
                escapedSubject,
                accessToken.Token,
                cancellationToken);
            using var request = new HttpRequestMessage(
                HttpMethod.Delete,
                $"v1.0/users/{escapedSubject}");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken.Token);

            using var response = await client.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            if (response.StatusCode is HttpStatusCode.NoContent or HttpStatusCode.NotFound)
            {
                return;
            }

            throw new AccountDeletionStepException(
                response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized
                    ? "external-identity-permission-denied"
                    : "external-identity-delete-failed",
                new HttpRequestException(
                    "Microsoft Graph rejected external identity deletion.",
                    inner: null,
                    response.StatusCode));
        }
        catch (AccountDeletionStepException)
        {
            throw;
        }
        catch (CredentialUnavailableException ex)
        {
            throw new AccountDeletionStepException(
                "external-identity-authentication-failed",
                ex);
        }
        catch (AuthenticationFailedException ex)
        {
            throw new AccountDeletionStepException(
                "external-identity-authentication-failed",
                ex);
        }
        catch (HttpRequestException ex)
        {
            throw new AccountDeletionStepException("external-identity-delete-failed", ex);
        }
        catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            throw new AccountDeletionStepException("external-identity-delete-timeout", ex);
        }
    }

    private async Task RevokeSessionsAsync(
        string escapedSubject,
        string accessToken,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"v1.0/users/{escapedSubject}/revokeSignInSessions");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        using var response = await client.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        if (response.IsSuccessStatusCode || response.StatusCode == HttpStatusCode.NotFound)
        {
            return;
        }

        throw new AccountDeletionStepException(
            response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized
                ? "external-session-revocation-permission-denied"
                : "external-session-revocation-failed",
            new HttpRequestException(
                "Microsoft Graph rejected session revocation.",
                inner: null,
                response.StatusCode));
    }
}

public sealed class DevelopmentExternalIdentityDeletion : IExternalIdentityDeletion
{
    public Task DeleteAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
        => Task.CompletedTask;
}

public sealed class UnavailableExternalIdentityDeletion : IExternalIdentityDeletion
{
    public Task DeleteAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
        => throw new AccountDeletionStepException(
            "external-identity-configuration-missing",
            new InvalidOperationException(
                "External identity deletion requires a Microsoft Graph confidential client."));
}
