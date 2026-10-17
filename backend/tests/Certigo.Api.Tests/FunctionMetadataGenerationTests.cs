using System.Reflection;
using System.Text.Json;
using Certigo.Api.Functions;
using FluentAssertions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Core.FunctionMetadata;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class FunctionMetadataGenerationTests
{
    [Fact]
    public async Task Generated_worker_metadata_preserves_every_declared_function_and_trigger()
    {
        var assembly = typeof(CatalogFunctions).Assembly;
        var providerType = assembly.GetTypes().Single(type =>
            typeof(IFunctionMetadataProvider).IsAssignableFrom(type)
            && !type.IsAbstract && !type.IsInterface);
        var provider = (IFunctionMetadataProvider)Activator.CreateInstance(providerType)!;
        var metadata = (await provider.GetFunctionMetadataAsync(assembly.Location)).ToArray();
        var declaredFunctions = assembly.GetTypes()
            .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.Instance))
            .Select(method => method.GetCustomAttribute<FunctionAttribute>())
            .Where(attribute => attribute is not null)
            .Select(attribute => attribute!.Name)
            .ToArray();

        declaredFunctions.Should().NotBeEmpty();
        metadata.Select(function => function.Name).Should().BeEquivalentTo(declaredFunctions);
        foreach (var function in metadata)
        {
            function.EntryPoint.Should().NotBeNullOrWhiteSpace();
            function.ScriptFile.Should().Be("Certigo.Api.dll");
            var rawBindings = function.RawBindings
                ?? throw new InvalidOperationException($"{function.Name} has no generated bindings.");
            var bindings = rawBindings.Select(binding =>
            {
                using var document = JsonDocument.Parse(binding);
                return document.RootElement.GetProperty("type").GetString();
            }).ToArray();
            bindings.Should().ContainSingle(binding =>
                binding != null && binding.EndsWith("Trigger", StringComparison.OrdinalIgnoreCase),
                $"{function.Name} must remain discoverable by the Functions host");
        }
    }
}
