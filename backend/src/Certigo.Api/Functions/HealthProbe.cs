using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using Azure.Core;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using Certigo.Infrastructure.Cosmos;

namespace Certigo.Api.Functions;

public interface IHealthProbe
{
    Task<ReadinessHealth> CheckAsync(CancellationToken cancellationToken);
}

public sealed record DependencyHealth(string Status, long DurationMs, string? ErrorCode = null)
{
    public bool IsHealthy => string.Equals(Status, "ok", StringComparison.Ordinal);
}

public sealed record ReadinessHealth(
    DependencyHealth Cosmos,
    DependencyHealth Storage,
    DependencyHealth KeyVault)
{
    public bool IsHealthy => Cosmos.IsHealthy && Storage.IsHealthy && KeyVault.IsHealthy;
}

internal sealed class AzureDependencyHealthProbe(
    CosmosContext cosmos,
    TokenCredential storageCredential,
    HttpClient httpClient,
    Uri blobEndpoint,
    string deploymentContainerName,
    Uri keyVaultUri,
    string keyVaultHealthSecretName,
    TimeSpan timeout,
    ILogger<AzureDependencyHealthProbe> logger) : IHealthProbe
{
    private const string StorageScope = "https://storage.azure.com/.default";
    private const string KeyVaultScope = "https://vault.azure.net/.default";

    public async Task<ReadinessHealth> CheckAsync(CancellationToken cancellationToken)
    {
        var cosmosCheck = RunCheckAsync(
            "Cosmos",
            async token =>
            {
                await cosmos.Users.ReadContainerAsync(cancellationToken: token);
            },
            cancellationToken);
        var storageCheck = RunCheckAsync("Storage", CheckStorageAsync, cancellationToken);
        var keyVaultCheck = RunCheckAsync("KeyVault", CheckKeyVaultAsync, cancellationToken);

        await Task.WhenAll(cosmosCheck, storageCheck, keyVaultCheck);
        return new ReadinessHealth(
            await cosmosCheck,
            await storageCheck,
            await keyVaultCheck);
    }

    private async Task CheckStorageAsync(CancellationToken cancellationToken)
    {
        var containerUri = new Uri(
            $"{blobEndpoint.AbsoluteUri.TrimEnd('/')}/{Uri.EscapeDataString(deploymentContainerName)}?restype=container");
        using var request = new HttpRequestMessage(HttpMethod.Get, containerUri);
        await AuthorizeAsync(request, storageCredential, StorageScope, cancellationToken);
        request.Headers.TryAddWithoutValidation("x-ms-version", "2023-11-03");
        request.Headers.TryAddWithoutValidation(
            "x-ms-date",
            DateTimeOffset.UtcNow.ToString("R", CultureInfo.InvariantCulture));
        using var response = await httpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        EnsureSuccess(response, "Storage");
    }

    private async Task CheckKeyVaultAsync(CancellationToken cancellationToken)
    {
        var secretUri = new Uri(
            $"{keyVaultUri.AbsoluteUri.TrimEnd('/')}/secrets/{Uri.EscapeDataString(keyVaultHealthSecretName)}?api-version=7.4");
        using var request = new HttpRequestMessage(HttpMethod.Get, secretUri);
        await AuthorizeAsync(request, storageCredential, KeyVaultScope, cancellationToken);
        using var response = await httpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        EnsureSuccess(response, "Key Vault");
    }

    private async Task AuthorizeAsync(
        HttpRequestMessage request,
        TokenCredential tokenCredential,
        string scope,
        CancellationToken cancellationToken)
    {
        var accessToken = await tokenCredential.GetTokenAsync(
            new TokenRequestContext([scope]),
            cancellationToken);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken.Token);
    }

    private async Task<DependencyHealth> RunCheckAsync(
        string dependency,
        Func<CancellationToken, Task> check,
        CancellationToken requestCancellationToken)
    {
        var startedAt = Stopwatch.GetTimestamp();
        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(requestCancellationToken);
        timeoutCts.CancelAfter(timeout);

        try
        {
            await check(timeoutCts.Token);
            return new DependencyHealth("ok", ElapsedMilliseconds(startedAt));
        }
        catch (OperationCanceledException ex) when (!requestCancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(
                ex,
                "Readiness dependency {Dependency} timed out after {TimeoutMs} ms.",
                dependency,
                timeout.TotalMilliseconds);
            return new DependencyHealth("error", ElapsedMilliseconds(startedAt), "timeout");
        }
        catch (Exception ex)
        {
            var errorCode = Classify(ex);
            logger.LogWarning(
                ex,
                "Readiness dependency {Dependency} failed with {ErrorCode}.",
                dependency,
                errorCode);
            return new DependencyHealth("error", ElapsedMilliseconds(startedAt), errorCode);
        }
    }

    private static long ElapsedMilliseconds(long startedAt)
        => (long)Stopwatch.GetElapsedTime(startedAt).TotalMilliseconds;

    private static string Classify(Exception exception)
    {
        var statusCode = exception switch
        {
            CosmosException cosmosException => cosmosException.StatusCode,
            HttpRequestException httpException => httpException.StatusCode,
            _ => null
        };

        return statusCode switch
        {
            HttpStatusCode.Unauthorized => "unauthorized",
            HttpStatusCode.Forbidden => "forbidden",
            HttpStatusCode.NotFound => "not-found",
            null when exception is HttpRequestException => "unreachable",
            _ => "dependency-error"
        };
    }

    private static void EnsureSuccess(HttpResponseMessage response, string dependency)
    {
        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"{dependency} readiness request returned HTTP {(int)response.StatusCode}.",
                null,
                response.StatusCode);
        }
    }
}
