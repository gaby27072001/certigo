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
        const string expectedUri = "https://kv-certigo-test.vault.azure.net/";
        const string expectedSecretName = "AUTH-JWT-SIGNING-KEY";

        Environment.SetEnvironmentVariable(uriVariable, expectedUri);
        Environment.SetEnvironmentVariable(healthSecretVariable, expectedSecretName);
        try
        {
            var configuration = new ConfigurationBuilder()
                .AddEnvironmentVariables(prefix)
                .Build();

            configuration[ConfigurationKeys.KeyVaultUri].Should().Be(expectedUri);
            configuration[ConfigurationKeys.KeyVaultHealthSecretName].Should().Be(expectedSecretName);
        }
        finally
        {
            Environment.SetEnvironmentVariable(uriVariable, null);
            Environment.SetEnvironmentVariable(healthSecretVariable, null);
        }
    }
}
