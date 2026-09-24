using System.Text.Json;
using System.Text.Json.Serialization;
using Certigo.Infrastructure.Cosmos;
using Microsoft.Azure.Cosmos;
using Xunit;

namespace Certigo.Infrastructure.Tests;

/// <summary>
/// Provisions a throw-away Cosmos database (one per fixture instance: per test class
/// through <see cref="IClassFixture{TFixture}"/>, or per test when a class owns the
/// fixture) against a locally-running Azure Cosmos DB emulator, seeds the production
/// container set, and tears the database down afterwards.
///
/// The whole suite is OPT-IN and gated behind <see cref="EnableFlag"/>: with the
/// flag unset — the default on a developer box or CI agent without an emulator —
/// every <see cref="CosmosEmulatorFactAttribute"/> test is reported as *skipped*
/// and this fixture never opens a connection, so the build stays green and
/// deterministic.
///
/// To run the tests for real, start the emulator and set:
/// <code>
///   CERTIGO_COSMOS_TESTS=1
///   COSMOS_EMULATOR_CONNECTION_STRING=&lt;emulator connection string&gt;
///       — or —
///   COSMOS_EMULATOR_ENDPOINT=https://localhost:8081   (this is the default)
///   COSMOS_EMULATOR_KEY=&lt;emulator primary key&gt;
/// </code>
/// The emulator's well-known primary key is published verbatim in Microsoft's
/// documentation; it is deliberately NOT hard-coded here so the repository carries
/// no credential-shaped strings.
/// </summary>
public sealed class CosmosEmulatorFixture : IAsyncLifetime
{
    public const string EnableFlag = "CERTIGO_COSMOS_TESTS";

    /// <summary>
    /// Trait carried by every class of emulator tests. The CI emulator gate selects the
    /// suite with <c>--filter Category=CosmosEmulator</c> and fails closed unless it
    /// executes exactly one passing result per <see cref="CosmosEmulatorFactAttribute"/>.
    /// </summary>
    public const string TraitName = "Category";

    public const string TraitValue = "CosmosEmulator";

    /// <summary>True only when the opt-in flag is explicitly set to "1".</summary>
    public static bool Enabled =>
        string.Equals(Environment.GetEnvironmentVariable(EnableFlag), "1", StringComparison.Ordinal);

    private readonly string _databaseName = $"certigo-itests-{Guid.NewGuid():N}";
    private readonly SemaphoreSlim _gate = new(1, 1);

    private CosmosClient? _client;
    private Database? _database;
    private CosmosContext? _context;

    // Lazy on purpose: no network at discovery/initialise time, so a fully-skipped
    // run (flag unset) never attempts to reach an emulator.
    public Task InitializeAsync() => Task.CompletedTask;

    /// <summary>
    /// Lazily creates the ephemeral database + the production containers on
    /// first use and returns a <see cref="CosmosContext"/> bound to them. Only ever
    /// reached from an executing (non-skipped) test body.
    /// </summary>
    public async Task<CosmosContext> GetContextAsync(CancellationToken cancellationToken = default)
    {
        if (_context is not null)
        {
            return _context;
        }

        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_context is not null)
            {
                return _context;
            }

            var client = CreateClient();
            var databaseResponse = await client.CreateDatabaseIfNotExistsAsync(
                _databaseName, cancellationToken: cancellationToken);
            var database = databaseResponse.Database;
            _client = client;
            _database = database;

            foreach (var definition in CosmosContainers.All)
            {
                var properties = new ContainerProperties(
                    definition.Name,
                    definition.PartitionKeyPath)
                {
                    DefaultTimeToLive = definition.DefaultTimeToLive
                };
                await database.CreateContainerIfNotExistsAsync(
                    properties,
                    cancellationToken: cancellationToken);
            }

            _context = new CosmosContext(client, _databaseName);
            return _context;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task DisposeAsync()
    {
        if (_database is not null)
        {
            try
            {
                await _database.DeleteAsync();
            }
            catch (CosmosException)
            {
                // Local emulator cleanup is best effort because stopping the
                // ephemeral container already removes every test document.
            }
        }

        _client?.Dispose();
        _gate.Dispose();
    }

    private static CosmosClient CreateClient()
    {
        // Mirror the production serializer wiring (Program.cs) exactly so the
        // camelCase property names and enum casing the repositories rely on
        // (e.g. submittedAt, userId, result.rewards.xpEarned) round-trip identically.
        var serializerOptions = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        serializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));

        var options = new CosmosClientOptions
        {
            Serializer = new CosmosSystemTextJsonSerializer(serializerOptions),
            // The emulator presents a self-signed certificate and is reached over the
            // gateway; both settings are appropriate only on this local-only path.
            ConnectionMode = ConnectionMode.Gateway,
            HttpClientFactory = () => new HttpClient(new HttpClientHandler
            {
                ServerCertificateCustomValidationCallback =
                    HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
            })
        };

        var connectionString = Environment.GetEnvironmentVariable("COSMOS_EMULATOR_CONNECTION_STRING");
        if (!string.IsNullOrWhiteSpace(connectionString))
        {
            return new CosmosClient(connectionString, options);
        }

        var endpoint = Environment.GetEnvironmentVariable("COSMOS_EMULATOR_ENDPOINT");
        if (string.IsNullOrWhiteSpace(endpoint))
        {
            endpoint = "https://localhost:8081";
        }

        var key = Environment.GetEnvironmentVariable("COSMOS_EMULATOR_KEY");
        if (string.IsNullOrWhiteSpace(key))
        {
            throw new InvalidOperationException(
                $"Cosmos emulator tests are enabled ({EnableFlag}=1) but no credentials were supplied. " +
                "Set COSMOS_EMULATOR_CONNECTION_STRING, or COSMOS_EMULATOR_KEY (optionally with " +
                "COSMOS_EMULATOR_ENDPOINT, default https://localhost:8081).");
        }

        return new CosmosClient(endpoint, key, options);
    }
}

/// <summary>
/// A <see cref="FactAttribute"/> that auto-skips unless the Cosmos emulator suite
/// is explicitly enabled (see <see cref="CosmosEmulatorFixture.EnableFlag"/>). The
/// skip decision is taken at construction/discovery time, so a gated-off run
/// reports these tests as *skipped* rather than performing any emulator I/O.
/// </summary>
public sealed class CosmosEmulatorFactAttribute : FactAttribute
{
    public CosmosEmulatorFactAttribute()
    {
        if (!CosmosEmulatorFixture.Enabled)
        {
            Skip =
                $"Cosmos emulator integration test — set {CosmosEmulatorFixture.EnableFlag}=1 " +
                "with a running emulator and COSMOS_EMULATOR_* configured to execute.";
        }
    }
}
