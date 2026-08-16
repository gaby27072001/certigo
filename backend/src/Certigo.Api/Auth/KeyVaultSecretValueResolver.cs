using System.Net.Http.Headers;
using System.Text.Json;
using Azure.Core;
using Azure.Identity;

namespace Certigo.Api.Auth;

internal static class KeyVaultSecretValueResolver
{
    private const string KeyVaultScope = "https://vault.azure.net/.default";

    public static string? Resolve(
        string? configuredValue,
        string? secretUri,
        string? managedIdentityClientId,
        TimeSpan timeout)
    {
        if (!string.IsNullOrWhiteSpace(configuredValue)
            && !configuredValue.TrimStart().StartsWith(
                "@Microsoft.KeyVault(",
                StringComparison.OrdinalIgnoreCase))
        {
            return configuredValue;
        }

        if (string.IsNullOrWhiteSpace(secretUri))
        {
            return configuredValue;
        }

        TokenCredential credential = string.IsNullOrWhiteSpace(managedIdentityClientId)
            ? new DefaultAzureCredential()
            : new ManagedIdentityCredential(
                ManagedIdentityId.FromUserAssignedClientId(managedIdentityClientId));
        using var httpClient = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        using var timeoutCts = new CancellationTokenSource(timeout);

        try
        {
            return ResolveAsync(
                    new Uri(secretUri, UriKind.Absolute),
                    credential,
                    httpClient,
                    timeoutCts.Token)
                .GetAwaiter()
                .GetResult();
        }
        catch (OperationCanceledException exception)
        {
            throw new InvalidOperationException(
                "Timed out while resolving a JWT signing secret from Key Vault.",
                exception);
        }
    }

    internal static async Task<string> ResolveAsync(
        Uri secretUri,
        TokenCredential credential,
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        ValidateSecretUri(secretUri);
        var requestUri = new UriBuilder(secretUri) { Query = "api-version=7.4" }.Uri;
        var accessToken = await credential.GetTokenAsync(
            new TokenRequestContext([KeyVaultScope]),
            cancellationToken);

        using var request = new HttpRequestMessage(HttpMethod.Get, requestUri);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken.Token);
        using var response = await httpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"Key Vault JWT signing secret request failed with HTTP {(int)response.StatusCode}.");
        }

        await using var responseStream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(
            responseStream,
            cancellationToken: cancellationToken);
        if (!document.RootElement.TryGetProperty("value", out var valueElement)
            || string.IsNullOrWhiteSpace(valueElement.GetString()))
        {
            throw new InvalidOperationException(
                "Key Vault JWT signing secret response did not contain a value.");
        }

        return valueElement.GetString()!;
    }

    private static void ValidateSecretUri(Uri secretUri)
    {
        var segments = secretUri.AbsolutePath
            .Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (!secretUri.Scheme.Equals(Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase)
            || !secretUri.Host.EndsWith(".vault.azure.net", StringComparison.OrdinalIgnoreCase)
            || segments.Length != 3
            || !segments[0].Equals("secrets", StringComparison.OrdinalIgnoreCase)
            || string.IsNullOrWhiteSpace(segments[1])
            || string.IsNullOrWhiteSpace(segments[2]))
        {
            throw new InvalidOperationException(
                "JWT signing secret URI must be a versioned Azure Key Vault secret URI.");
        }
    }
}
