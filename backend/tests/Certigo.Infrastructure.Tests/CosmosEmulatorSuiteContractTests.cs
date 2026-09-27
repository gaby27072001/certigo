using System.Reflection;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

/// <summary>
/// Keeps the CI emulator gate (<c>infra/ci-runner/cosmos-emulator/run-account-deletion.sh</c>)
/// honest without an emulator: the gate selects <c>Category=CosmosEmulator</c> and requires
/// one passing result per <see cref="CosmosEmulatorFactAttribute"/>, so an emulator test
/// outside the trait, or a plain test inside it, would make the gate count wrong.
/// </summary>
public sealed class CosmosEmulatorSuiteContractTests
{
    private const BindingFlags TestMethodFlags =
        BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic
        | BindingFlags.DeclaredOnly;

    [Fact]
    public void Every_emulator_test_belongs_to_a_class_selected_by_the_gate_trait()
    {
        var emulatorTests = TestTypes()
            .SelectMany(type => type.GetMethods(TestMethodFlags))
            .Where(method => method.GetCustomAttribute<CosmosEmulatorFactAttribute>() is not null)
            .ToList();

        emulatorTests.Should().NotBeEmpty();
        emulatorTests.Should().Contain(method =>
            method.Name == "Account_deletion_removes_user_partitions_and_keeps_only_pseudonymous_tombstone");
        emulatorTests
            .Where(method => !HasGateTrait(method.DeclaringType!))
            .Select(method => $"{method.DeclaringType!.Name}.{method.Name}")
            .Should().BeEmpty("the CI gate filters on {0}={1}",
                CosmosEmulatorFixture.TraitName,
                CosmosEmulatorFixture.TraitValue);
    }

    [Fact]
    public void Gate_trait_selects_only_emulator_tests()
    {
        var gateClasses = TestTypes().Where(HasGateTrait).ToList();

        gateClasses.Should().NotBeEmpty();
        gateClasses
            .SelectMany(type => type.GetMethods(TestMethodFlags))
            .Where(method => method.GetCustomAttributes<FactAttribute>(inherit: true).Any())
            .Where(method => method.GetCustomAttribute<CosmosEmulatorFactAttribute>() is null)
            .Select(method => $"{method.DeclaringType!.Name}.{method.Name}")
            .Should().BeEmpty("the gate expects exactly one result per [CosmosEmulatorFact]");
    }

    private static IEnumerable<Type> TestTypes() =>
        typeof(CosmosEmulatorFixture).Assembly.GetTypes().Where(type => type.IsClass);

    private static bool HasGateTrait(Type type) =>
        type.GetCustomAttributesData().Any(attribute =>
            attribute.AttributeType == typeof(TraitAttribute)
            && attribute.ConstructorArguments.Count == 2
            && Equals(attribute.ConstructorArguments[0].Value, CosmosEmulatorFixture.TraitName)
            && Equals(attribute.ConstructorArguments[1].Value, CosmosEmulatorFixture.TraitValue));
}
