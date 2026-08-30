using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class OrganizationMembershipContractTests
{
    [Fact]
    public void Versioned_contract_is_off_only_and_preserves_person_ownership()
    {
        using var openApi = Load("openapi.json");
        var root = openApi.RootElement;

        root.GetProperty("info").GetProperty("version").GetString().Should().Be("1.1.0");
        root.GetProperty("x-certigo-feature-mode")
            .GetProperty("implementedValues")
            .EnumerateArray()
            .Select(value => value.GetString())
            .Should()
            .Equal("off");
        root.GetProperty("x-certigo-person-contract")
            .GetProperty("automaticEmailMerge")
            .GetBoolean()
            .Should()
            .BeFalse();
        root.GetProperty("x-certigo-person-contract")
            .GetProperty("personalLearningOwnership")
            .GetString()
            .Should()
            .Be("personId");
        var authorization = root.GetProperty("x-certigo-authorization");
        authorization.GetProperty("clientClaimsTrusted").GetBoolean().Should().BeFalse();
        authorization.GetProperty("emailTrusted").GetBoolean().Should().BeFalse();
        authorization.GetProperty("crossTenantHttpStatus").GetInt32().Should().Be(404);
        authorization.GetProperty("permissionMatrix")
            .GetProperty("manageAssignments")
            .EnumerateArray()
            .Select(value => value.GetString())
            .Should()
            .Equal("owner", "admin", "manager");
    }

    [Fact]
    public void Cosmos_contract_is_additive_partition_local_and_ttl_enabled()
    {
        using var schema = Load("cosmos.schema.json");
        var cosmos = schema.RootElement.GetProperty("x-certigo-cosmos");

        cosmos.GetProperty("container").GetString().Should().Be("organizations");
        cosmos.GetProperty("partitionKey").GetString().Should().Be("/organizationId");
        cosmos.GetProperty("defaultTtl").GetInt32().Should().Be(-1);
        cosmos.GetProperty("existingContainersChanged").GetBoolean().Should().BeFalse();
    }

    private static JsonDocument Load(string fileName)
    {
        var root = FindRepositoryRoot();
        return JsonDocument.Parse(File.ReadAllText(
            Path.Combine(
                root,
                "docs",
                "contracts",
                "organization-membership",
                "v1",
                fileName)));
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null && !Directory.Exists(Path.Combine(current.FullName, "docs")))
        {
            current = current.Parent;
        }
        return current?.FullName
            ?? throw new InvalidOperationException("Repository root was not found.");
    }
}
