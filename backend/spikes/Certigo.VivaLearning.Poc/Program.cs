using Certigo.VivaLearning.Poc;

if (args.Contains("--help", StringComparer.OrdinalIgnoreCase))
{
    Console.WriteLine(
        """
        Certigo Viva Learning contractual POC

        This executable never contacts a tenant. It replays contractual Microsoft Graph fixtures.

        Usage:
          $env:CERTIGO_VIVA_LEARNING_POC_ENABLED = "true"
          dotnet run --project backend\spikes\Certigo.VivaLearning.Poc -- --non-interactive
        """);
    return 0;
}

if (!VivaLearningPocGate.IsEnabled(
        Environment.GetEnvironmentVariable(VivaLearningPocGate.FeatureFlag)))
{
    Console.Error.WriteLine(
        $"POC disabled. Set {VivaLearningPocGate.FeatureFlag}=true to run the offline simulator.");
    return 3;
}

var nonInteractive = args.Contains("--non-interactive", StringComparer.OrdinalIgnoreCase);
if (!nonInteractive)
{
    Console.WriteLine("OFFLINE ONLY: no token, consent, tenant, provider, or live Graph call will be used.");
    Console.Write("Type SIMULATE to replay the contractual fixtures: ");
    if (!string.Equals(Console.ReadLine(), "SIMULATE", StringComparison.Ordinal))
    {
        Console.Error.WriteLine("Cancelled without side effects.");
        return 2;
    }
}

var fixtureDirectory = Path.Combine(AppContext.BaseDirectory, "Fixtures");
var handler = new FixtureGraphMessageHandler(fixtureDirectory);
using var httpClient = new HttpClient(handler);
var graphClient = new VivaLearningGraphClient(
    httpClient,
    new VivaLearningPocOptions(
        Enabled: true,
        GraphBaseUri: new Uri("https://graph.microsoft.com/v1.0/")));
var scenario = new VivaLearningPocScenario(
    graphClient,
    new CertigoVivaLearningAdapter(new Uri("https://certigo.invalid/")));

var result = await scenario.RunAsync(
    new DateTimeOffset(2026, 8, 19, 12, 15, 0, TimeSpan.Zero));

Console.WriteLine();
Console.WriteLine("Contractual flow: PASS");
Console.WriteLine($"Provider: {result.Provider.Id}");
Console.WriteLine($"Content:  {result.Content.ExternalId} -> {result.DeepLink}");
Console.WriteLine($"Assignment: {result.Assignment.Id}");
Console.WriteLine($"Progress: {result.InProgress.CompletionPercentage}% -> {result.Completed.Status}");
Console.WriteLine($"Captured Graph requests: {handler.Requests.Count}");
Console.WriteLine();
Console.WriteLine("Authorization split to validate in a licensed non-production tenant:");
foreach (var operation in VivaLearningOperationContract.All)
{
    Console.WriteLine(
        $"- {operation.Operation}: {operation.AuthMode} / {operation.Permission}");
}

Console.WriteLine();
Console.WriteLine("GO: offline request, response, mapping, and progress contracts.");
Console.WriteLine("NO-GO: live integration until the consent runbook and HTTPS app-link test pass.");
return 0;
