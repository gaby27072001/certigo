using Certigo.Api;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ConfigurationKeysTests
{
    [Fact]
    public void KeyVaultSettings_UseCanonicalKeysForEnvironmentVariables()
    {
        var prefix = $"CERTIGO_TEST_{Guid.NewGuid():N}_";
        var uriVariable = $"{prefix}KeyVault__Uri";
        var healthSecretVariable = $"{prefix}KeyVault__HealthSecretName";
        var graphSecretUriVariable = $"{prefix}ENTRA_GRAPH_CLIENT_SECRET_SECRET_URI";
        const string expectedUri = "https://kv-certigo-test.vault.azure.net/";
        const string expectedSecretName = "AUTH-JWT-SIGNING-KEY";
        const string expectedGraphSecretUri =
            "https://kv-certigo-test.vault.azure.net/secrets/graph-client/version";

        Environment.SetEnvironmentVariable(uriVariable, expectedUri);
        Environment.SetEnvironmentVariable(healthSecretVariable, expectedSecretName);
        Environment.SetEnvironmentVariable(graphSecretUriVariable, expectedGraphSecretUri);
        try
        {
            var configuration = new ConfigurationBuilder()
                .AddEnvironmentVariables(prefix)
                .Build();

            configuration[ConfigurationKeys.KeyVaultUri].Should().Be(expectedUri);
            configuration[ConfigurationKeys.KeyVaultHealthSecretName].Should().Be(expectedSecretName);
            configuration[ConfigurationKeys.EntraGraphClientSecretSecretUri]
                .Should().Be(expectedGraphSecretUri);
        }
        finally
        {
            Environment.SetEnvironmentVariable(uriVariable, null);
            Environment.SetEnvironmentVariable(healthSecretVariable, null);
            Environment.SetEnvironmentVariable(graphSecretUriVariable, null);
        }
    }
}
