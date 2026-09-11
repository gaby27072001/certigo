using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Domain.Content;
using FluentAssertions;
using Microsoft.Azure.Functions.Worker;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// Compares the OpenAPI documents under <c>docs/contracts/</c> with the HTTP surface the
/// backend actually declares, read by reflection over the real <c>HttpTrigger</c> attributes.
///
/// The existing contract tests (Organization membership, Person/LinkedIdentity, runtime
/// content) assert that a contract is internally consistent. None of them asks the
/// complementary question: <em>does the code still look like this?</em> A contract that is
/// never compared with the code degrades into documentation that lies, and the lie is
/// silent — every other signal stays green.
///
/// Two directions are checked, because only the second one catches drift by omission:
/// contract to code (nothing is documented that does not exist) and code to contract
/// (nothing exists that is neither documented nor explicitly deferred in
/// <c>docs/contracts/deferred-routes.json</c>). Adding a route therefore fails the build
/// until somebody either contracts it or records why not.
///
/// Every scan carries a reading floor: an instrument that read nothing must fail rather
/// than return zero, otherwise a renamed attribute or a moved file would turn each
/// assertion below into a vacuous pass (docs/GOVERNANCE.md section 7).
/// </summary>
public sealed class ApiSurfaceContractTests
{
    // Reading floors. Deliberately well below the measured values (86 backend operations,
    // 7 contracts, 61 contracted operations on 2026-09-11) so ordinary growth or removal
    // never trips them, yet an instrument that stops reading does.
    private const int MinimumBackendOperations = 70;
    private const int MinimumContractDocuments = 5;
    private const int MinimumContractOperations = 45;
    private const int MinimumAnonymousPaths = 8;

    private static readonly string[] HttpVerbs =
        ["get", "put", "post", "delete", "patch", "head", "options", "trace"];

    [Fact]
    public void Every_contracted_operation_exists_in_the_backend()
    {
        var backend = BackendOperations();
        var contracted = ContractOperations();

        var lies = contracted
            .Where(entry => entry.Value.Implemented && !backend.ContainsKey(entry.Key))
            .Select(entry => $"{entry.Key} (contrat {entry.Value.Domain})")
            .OrderBy(text => text)
            .ToArray();

        lies.Should().BeEmpty(
            "un contrat qui declare une route absente du backend est une documentation qui ment ; "
            + "si l'operation est volontairement non livree, marquez-la "
            + "\"x-certigo-implemented\": false dans son document OpenAPI");
    }

    [Fact]
    public void Every_backend_operation_is_contracted_or_explicitly_deferred()
    {
        var backend = BackendOperations();
        var contracted = ContractOperations();
        var deferred = DeferredOperations();

        var undocumented = backend.Keys
            .Where(operation => !contracted.ContainsKey(operation))
            .Where(operation => !deferred.ContainsKey(operation))
            .Select(operation => $"{operation} (declaree dans {backend[operation]})")
            .OrderBy(text => text)
            .ToArray();

        undocumented.Should().BeEmpty(
            "toute route HTTP doit etre soit decrite dans docs/contracts/<domaine>/v1/openapi.json, "
            + "soit inscrite avec une raison dans docs/contracts/deferred-routes.json ; "
            + "sans ce cliquet, deux applications natives divergent sans qu'aucun signal ne rougisse");
    }

    [Fact]
    public void Deferred_ledger_contains_no_stale_or_ambiguous_entry()
    {
        var backend = BackendOperations();
        var contracted = ContractOperations();
        var deferred = DeferredOperations();

        deferred.Should().NotBeEmpty("le registre des routes differees doit etre lu pour que ce test signifie quelque chose");

        var stale = deferred.Keys
            .Where(operation => !backend.ContainsKey(operation))
            .OrderBy(text => text)
            .ToArray();
        stale.Should().BeEmpty(
            "une entree differee qui ne correspond plus a aucune route backend masque une suppression "
            + "ou une renommee ; retirez-la du registre");

        var ambiguous = deferred.Keys
            .Where(operation => contracted.ContainsKey(operation))
            .OrderBy(text => text)
            .ToArray();
        ambiguous.Should().BeEmpty(
            "une route ne peut pas etre a la fois contractee et differee : retirez-la du registre "
            + "une fois son contrat ecrit");

        deferred.Values.Should().OnlyContain(
            reason => !string.IsNullOrWhiteSpace(reason),
            "chaque report doit porter sa raison, sinon le registre devient une decharge");
    }

    [Fact]
    public void Contracted_anonymity_matches_the_authentication_middleware()
    {
        var anonymousPaths = MiddlewareAnonymousPaths();
        var contracted = ContractOperations();

        // Controle de presence : si la liste du middleware devient illisible (champ renomme,
        // classe deplacee), ce test doit echouer au lieu de comparer deux ensembles vides.
        anonymousPaths.Should().HaveCountGreaterThanOrEqualTo(
            MinimumAnonymousPaths,
            "la liste AnonymousPaths de JwtAuthMiddleware doit etre lue pour que la comparaison ait un sens");
        anonymousPaths.Should().Contain(
            "/api/auth/login",
            "temoin positif : l'instrument doit savoir rendre une presence connue");

        // Direction critique pour la securite, inconditionnelle : une route que le middleware
        // laisse passer sans jeton DOIT etre documentee comme anonyme. L'oubli inverse est une
        // surface publique non documentee.
        var undocumentedPublic = contracted
            .Where(entry => anonymousPaths.Contains($"/api{RouteOf(entry.Key)}"))
            .Where(entry => !entry.Value.Anonymous)
            .Select(entry => $"{entry.Key} (contrat {entry.Value.Domain})")
            .OrderBy(text => text)
            .ToArray();
        undocumentedPublic.Should().BeEmpty(
            "JwtAuthMiddleware sert ces routes sans jeton porteur : le contrat doit le declarer "
            + "par \"security\": [], sinon il decrit une protection qui n'existe pas");

        // Direction inverse : un contrat peut legitimement declarer anonyme une operation que
        // JwtAuthMiddleware protegerait, a condition qu'une porte de fonctionnalite reponde
        // AVANT l'authentification de route. Cette exemption doit etre declaree dans le document
        // lui-meme (x-certigo-feature-mode.evaluationOrder), jamais supposee ici.
        var unjustifiedAnonymous = contracted
            .Where(entry => !anonymousPaths.Contains($"/api{RouteOf(entry.Key)}"))
            .Where(entry => entry.Value.Anonymous && !entry.Value.PreAuthenticationFeatureGate)
            .Select(entry => $"{entry.Key} (contrat {entry.Value.Domain})")
            .OrderBy(text => text)
            .ToArray();
        unjustifiedAnonymous.Should().BeEmpty(
            "AuthorizationLevel.Anonymous sur le HttpTrigger ne decrit pas la frontiere "
            + "d'authentification : toutes les fonctions la declarent. Une operation ne peut se "
            + "dire anonyme que si AnonymousPaths la contient, ou si son document declare une "
            + "porte de fonctionnalite evaluee avant l'authentification de route");
    }

    [Fact]
    public void Critical_path_submissions_stay_idempotent_and_owner_implicit()
    {
        using var journey = LoadContract("learning-journey");
        var schemas = journey.RootElement.GetProperty("components").GetProperty("schemas");

        foreach (var schemaName in new[] { "SubmitQuizRequest", "SubmitMockExamRequest" })
        {
            var schema = schemas.GetProperty(schemaName);
            schema.GetProperty("required").EnumerateArray().Select(value => value.GetString())
                .Should().Contain(
                    "clientAttemptId",
                    $"{schemaName} doit conserver la cle d'idempotence de soumission");

            var properties = schema.GetProperty("properties").EnumerateObject()
                .Select(property => property.Name)
                .ToArray();
            properties.Should().NotContain(
                name => name.Equals("userId", System.StringComparison.OrdinalIgnoreCase)
                    || name.Equals("personId", System.StringComparison.OrdinalIgnoreCase)
                    || name.Equals("ownerId", System.StringComparison.OrdinalIgnoreCase),
                $"{schemaName} ne doit jamais accepter une identite depuis le corps : "
                + "le proprietaire est derive du JWT valide");
        }

        journey.RootElement.GetProperty("x-certigo-authorization")
            .GetProperty("ownerAcceptedFromRequestBody").GetBoolean().Should().BeFalse();
        journey.RootElement.GetProperty("x-certigo-scoring")
            .GetProperty("authority").GetString().Should().Be("server");
    }

    [Fact]
    public void Public_lesson_schema_exposes_no_more_than_the_public_domain_model()
    {
        using var journey = LoadContract("learning-journey");
        var contractFields = journey.RootElement
            .GetProperty("components").GetProperty("schemas").GetProperty("LessonCheck")
            .GetProperty("properties").EnumerateObject()
            .Select(property => property.Name)
            .ToArray();

        var publicFields = typeof(LessonCheck).GetProperties()
            .Select(property => JsonNamingPolicy.CamelCase.ConvertName(property.Name))
            .ToArray();

        // Controle de presence avant toute conclusion d'absence.
        publicFields.Should().Contain("stem", "le modele public LessonCheck doit etre lu");

        contractFields.Should().BeEquivalentTo(
            publicFields,
            "le schema public du contrat doit refleter exactement LessonCheck ; le corrige vit "
            + "dans LessonAnswerKey, cote serveur, et n'est jamais envoye au client");

        var answerKeyOnly = typeof(AnswerKeyItem).GetProperties()
            .Select(property => JsonNamingPolicy.CamelCase.ConvertName(property.Name))
            .Where(name => name is "correct" or "explanation")
            .ToArray();
        answerKeyOnly.Should().HaveCount(2, "les champs reserves au corrige doivent etre lus");
        contractFields.Should().NotIntersectWith(
            answerKeyOnly,
            "aucun champ du corrige ne doit apparaitre dans la charge utile publique d'un item");
    }

    // --- Lecture du backend ---------------------------------------------------------

    /// <summary>Operations HTTP reellement declarees, "VERBE /route-normalisee".</summary>
    private static IReadOnlyDictionary<string, string> BackendOperations()
    {
        var operations = new Dictionary<string, string>(System.StringComparer.Ordinal);
        var triggers = 0;

        foreach (var type in typeof(ContentReleaseFunctions).Assembly.GetTypes())
        {
            var methods = type.GetMethods(
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance
                | BindingFlags.Static | BindingFlags.DeclaredOnly);

            foreach (var method in methods)
            {
                if (method.GetCustomAttribute<FunctionAttribute>() is null)
                {
                    continue;
                }

                foreach (var parameter in method.GetParameters())
                {
                    var trigger = parameter.GetCustomAttribute<HttpTriggerAttribute>();
                    if (trigger is null || trigger.Route is not { Length: > 0 } route)
                    {
                        continue;
                    }

                    triggers++;
                    foreach (var verb in trigger.Methods ?? [])
                    {
                        if (verb.Equals("options", System.StringComparison.OrdinalIgnoreCase))
                        {
                            continue;
                        }

                        operations[$"{verb.ToUpperInvariant()} {Normalize(route)}"] = type.Name;
                    }
                }
            }
        }

        triggers.Should().BeGreaterThan(
            0,
            "la reflexion doit observer les attributs HttpTrigger de Certigo.Api");
        operations.Should().HaveCountGreaterThanOrEqualTo(
            MinimumBackendOperations,
            $"seules {operations.Count} operations HTTP ont ete lues : sous le plancher de "
            + $"{MinimumBackendOperations}, l'instrument ne mesure plus rien et doit echouer "
            + "plutot que de rendre une couverture flatteuse");
        return operations;
    }

    /// <summary>Liste AnonymousPaths de JwtAuthMiddleware, seule autorite sur l'anonymat.</summary>
    private static IReadOnlySet<string> MiddlewareAnonymousPaths()
    {
        var field = typeof(JwtAuthMiddleware).GetField(
            "AnonymousPaths",
            BindingFlags.NonPublic | BindingFlags.Static);
        field.Should().NotBeNull(
            "JwtAuthMiddleware.AnonymousPaths porte la frontiere d'authentification ; si ce champ "
            + "est renomme, ce test doit echouer au lieu de comparer deux ensembles vides");

        var value = field!.GetValue(null) as HashSet<string>;
        value.Should().NotBeNull("AnonymousPaths doit rester un HashSet<string> lisible par ce test");
        return value!;
    }

    // --- Lecture des contrats -------------------------------------------------------

    private sealed record ContractOperation(
        string Domain,
        bool Anonymous,
        bool Implemented,
        bool PreAuthenticationFeatureGate);

    private static IReadOnlyDictionary<string, ContractOperation> ContractOperations()
    {
        var contractsRoot = Path.Combine(RepositoryRoot(), "docs", "contracts");
        var operations = new Dictionary<string, ContractOperation>(System.StringComparer.Ordinal);
        var documents = 0;

        foreach (var domainDirectory in Directory.GetDirectories(contractsRoot))
        {
            var file = Path.Combine(domainDirectory, "v1", "openapi.json");
            if (!File.Exists(file))
            {
                continue;
            }

            documents++;
            var domain = Path.GetFileName(domainDirectory);
            using var document = JsonDocument.Parse(File.ReadAllText(file));
            var root = document.RootElement;

            // servers[0].url vaut "/api", qui est le routePrefix par defaut d'Azure Functions
            // (aucun override dans host.json). Il n'appartient donc pas au template Route =,
            // et les chemins OpenAPI se comparent directement aux routes declarees.
            var server = root.TryGetProperty("servers", out var servers) && servers.GetArrayLength() > 0
                ? servers[0].GetProperty("url").GetString()
                : string.Empty;
            server.Should().BeOneOf(
                [string.Empty, "/api"],
                $"une base serveur inattendue dans {domain} invaliderait la normalisation des routes");

            var rootIsAnonymous = root.TryGetProperty("security", out var rootSecurity)
                && rootSecurity.GetArrayLength() == 0;

            // Une porte de fonctionnalite qui repond avant l'authentification de route rend une
            // operation joignable sans jeton alors qu'AnonymousPaths ne la contient pas. Ce fait
            // est lu dans le document, jamais suppose. Il est lui-meme garde cote code : voir
            // EnterpriseIdentityFeatureTests.Disabled_surface_returns_404_before_authentication,
            // qui verifie que le validateur de jeton n'est jamais appele.
            var preAuthenticationFeatureGate = false;
            if (root.TryGetProperty("x-certigo-feature-mode", out var featureMode)
                && featureMode.TryGetProperty("evaluationOrder", out var evaluationOrder))
            {
                var steps = evaluationOrder.EnumerateArray()
                    .Select(step => step.GetString())
                    .ToList();
                var gate = steps.IndexOf("feature gate");
                var authentication = steps.IndexOf("route authentication");
                preAuthenticationFeatureGate = gate >= 0 && authentication > gate;
            }

            if (!root.TryGetProperty("paths", out var paths))
            {
                continue;
            }

            foreach (var path in paths.EnumerateObject())
            {
                foreach (var operation in path.Value.EnumerateObject())
                {
                    if (!HttpVerbs.Contains(operation.Name))
                    {
                        continue;
                    }

                    var anonymous = operation.Value.TryGetProperty("security", out var security)
                        ? security.GetArrayLength() == 0
                        : rootIsAnonymous;
                    var implemented =
                        !operation.Value.TryGetProperty("x-certigo-implemented", out var flag)
                        || flag.GetBoolean();

                    operations[$"{operation.Name.ToUpperInvariant()} {Normalize(path.Name)}"] =
                        new ContractOperation(
                            domain,
                            anonymous,
                            implemented,
                            preAuthenticationFeatureGate);
                }
            }
        }

        documents.Should().BeGreaterThanOrEqualTo(
            MinimumContractDocuments,
            $"seuls {documents} documents OpenAPI ont ete lus sous {contractsRoot}");
        operations.Should().HaveCountGreaterThanOrEqualTo(
            MinimumContractOperations,
            $"seules {operations.Count} operations contractuelles ont ete lues : sous le plancher "
            + $"de {MinimumContractOperations}, l'instrument ne mesure plus rien");
        return operations;
    }

    private static IReadOnlyDictionary<string, string> DeferredOperations()
    {
        var file = Path.Combine(RepositoryRoot(), "docs", "contracts", "deferred-routes.json");
        File.Exists(file).Should().BeTrue($"{file} porte le registre des routes non contractees");

        using var document = JsonDocument.Parse(File.ReadAllText(file));
        document.RootElement.GetProperty("schema").GetString()
            .Should().Be("certigo.api-surface.deferred/v1");

        var deferred = new Dictionary<string, string>(System.StringComparer.Ordinal);
        foreach (var entry in document.RootElement.GetProperty("deferred").EnumerateArray())
        {
            deferred[entry.GetProperty("operation").GetString()!] =
                entry.GetProperty("reason").GetString() ?? string.Empty;
        }

        return deferred;
    }

    private static JsonDocument LoadContract(string domain) => JsonDocument.Parse(
        File.ReadAllText(Path.Combine(
            RepositoryRoot(), "docs", "contracts", domain, "v1", "openapi.json")));

    // --- Outillage ------------------------------------------------------------------

    /// <summary>Remplace chaque segment parametre par "{}" pour comparer des formes de route.</summary>
    private static string Normalize(string route)
    {
        var segments = route.Trim('/')
            .Split('/', System.StringSplitOptions.RemoveEmptyEntries)
            .Select(segment => segment.StartsWith('{') ? "{}" : segment);
        return "/" + string.Join('/', segments);
    }

    /// <summary>Extrait la route d'une cle "VERBE /route".</summary>
    private static string RouteOf(string operation) => operation[(operation.IndexOf(' ') + 1)..];

    private static string RepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null
            && !Directory.Exists(Path.Combine(current.FullName, "docs", "contracts")))
        {
            current = current.Parent;
        }

        return current?.FullName
            ?? throw new InvalidOperationException(
                $"docs/contracts introuvable en remontant depuis {AppContext.BaseDirectory}");
    }
}
