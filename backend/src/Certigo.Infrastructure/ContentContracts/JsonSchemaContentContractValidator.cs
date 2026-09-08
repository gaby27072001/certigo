using System.Reflection;
using System.Text.Json;
using Certigo.Application.Abstractions;
using Json.Schema;

namespace Certigo.Infrastructure.ContentContracts;

public sealed class JsonSchemaContentContractValidator : IContentSchemaValidator
{
    private static readonly Lazy<IReadOnlyDictionary<string, JsonSchema>> SharedSchemas =
        new(LoadSchemas, LazyThreadSafetyMode.ExecutionAndPublication);

    private readonly IReadOnlyDictionary<string, JsonSchema> _schemas = SharedSchemas.Value;

    private static IReadOnlyDictionary<string, JsonSchema> LoadSchemas()
    {
        var assembly = typeof(JsonSchemaContentContractValidator).Assembly;
        return assembly.GetManifestResourceNames()
            .Where(name => name.Contains(".ContentContracts.Schemas.", StringComparison.Ordinal)
                           && name.EndsWith(".json", StringComparison.Ordinal))
            .ToDictionary(
                name => SchemaFileName(name),
                name => LoadSchema(assembly, name),
                StringComparer.Ordinal);
    }

    public void Validate(string schemaFileName, JsonElement value)
    {
        if (!_schemas.TryGetValue(schemaFileName, out var schema))
        {
            throw new ContentReleaseValidationException(
                $"Embedded content schema '{schemaFileName}' is unavailable.");
        }

        var result = schema.Evaluate(value, new EvaluationOptions
        {
            OutputFormat = OutputFormat.List,
            RequireFormatValidation = true,
        });
        if (!result.IsValid)
        {
            throw new ContentReleaseValidationException(
                $"Content does not satisfy embedded schema '{schemaFileName}'.");
        }
    }

    private static JsonSchema LoadSchema(Assembly assembly, string resourceName)
    {
        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException($"Embedded schema '{resourceName}' was not found.");
        using var reader = new StreamReader(stream);
        return JsonSchema.FromText(reader.ReadToEnd());
    }

    private static string SchemaFileName(string resourceName)
    {
        const string marker = ".ContentContracts.Schemas.";
        var start = resourceName.IndexOf(marker, StringComparison.Ordinal) + marker.Length;
        return resourceName[start..];
    }
}
