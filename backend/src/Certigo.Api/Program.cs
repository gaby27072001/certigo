using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Communication.Email;
using Azure.Core;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.ApplicationInsights;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Certigo.Api;
using Certigo.Api.Auth;
using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Infrastructure.Ai;
using Certigo.Infrastructure.Cosmos;
using Certigo.Infrastructure.Email;
using Certigo.Infrastructure.Identity;
using Certigo.Infrastructure.Observability;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults(worker =>
    {
        // Order matters: SecurityHeadersMiddleware is outermost so it stamps security
        // headers on every response (including the error/401 responses written by the
        // middleware below). ExceptionMiddleware then wraps JwtAuthMiddleware so any
        // downstream exception is mapped to ProblemDetails.
        worker.UseMiddleware<SecurityHeadersMiddleware>();
        worker.UseMiddleware<ExceptionMiddleware>();
        worker.UseMiddleware<JwtAuthMiddleware>();
    })
    .ConfigureServices((context, services) =>
    {
        var configuration = context.Configuration;
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        services.AddSingleton<TokenCredential, DefaultAzureCredential>();
        services.AddSingleton(sp =>
        {
            var endpoint = configuration["COSMOS_ENDPOINT"]
                ?? throw new InvalidOperationException("COSMOS_ENDPOINT is required.");
            var credential = sp.GetRequiredService<TokenCredential>();
            var serializerOptions = new JsonSerializerOptions(JsonSerializerDefaults.Web);
            serializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
            return new CosmosClient(endpoint, credential, new CosmosClientOptions
            {
                Serializer = new CosmosSystemTextJsonSerializer(serializerOptions)
            });
        });
        services.AddSingleton(sp => new CosmosContext(
            sp.GetRequiredService<CosmosClient>(),
            configuration["COSMOS_DATABASE"] ?? CosmosContainers.DatabaseName));
        services.AddHttpClient("HealthProbe", client => client.Timeout = Timeout.InfiniteTimeSpan);
        services.AddSingleton<IHealthProbe>(sp =>
        {
            var blobEndpoint = configuration["BLOB_ENDPOINT"]
                ?? throw new InvalidOperationException("BLOB_ENDPOINT is required.");
            var deploymentContainerName = configuration["DEPLOYMENT_CONTAINER_NAME"]
                ?? throw new InvalidOperationException("DEPLOYMENT_CONTAINER_NAME is required.");
            var keyVaultUri = configuration[ConfigurationKeys.KeyVaultUri]
                ?? throw new InvalidOperationException("KeyVault__Uri is required.");
            var keyVaultHealthSecretName = configuration[ConfigurationKeys.KeyVaultHealthSecretName]
                ?? "AUTH-JWT-SIGNING-KEY";
            var defaultCredential = sp.GetRequiredService<TokenCredential>();
            var platformClientId = configuration["HEALTH_PLATFORM_CLIENT_ID"];
            TokenCredential storageCredential = string.IsNullOrWhiteSpace(platformClientId)
                ? defaultCredential
                : new ManagedIdentityCredential(
                    ManagedIdentityId.FromUserAssignedClientId(platformClientId));
            var timeoutSeconds = int.TryParse(
                configuration["HEALTH_PROBE_TIMEOUT_SECONDS"],
                out var configuredTimeoutSeconds)
                && configuredTimeoutSeconds > 0
                ? configuredTimeoutSeconds
                : 5;

            return new AzureDependencyHealthProbe(
                sp.GetRequiredService<CosmosContext>(),
                storageCredential,
                sp.GetRequiredService<IHttpClientFactory>().CreateClient("HealthProbe"),
                new Uri(blobEndpoint, UriKind.Absolute),
                deploymentContainerName,
                new Uri(keyVaultUri, UriKind.Absolute),
                keyVaultHealthSecretName,
                TimeSpan.FromSeconds(timeoutSeconds),
                sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<AzureDependencyHealthProbe>>());
        });

        // Locally-issued JWT settings shared by the issuer and the local validator.
        // The signing key is mandatory in a hardened environment (Production or
        // AUTH_MODE=prod): a missing, blank, or default dev key fails fast at startup
        // so a weak, publicly-known key can never sign tokens in production. Outside
        // production a fixed dev key is tolerated so the email/password flow works out
        // of the box locally. The decision is a pure, unit-tested function.
        var signingSecret = JwtSigningKeyGuard.ResolveSigningSecret(
            configuration["AUTH_JWT_SIGNING_KEY"],
            context.HostingEnvironment.IsProduction(),
            configuration["AUTH_MODE"]);
        var previousSigningSecret = JwtSigningKeyGuard.ResolvePreviousSigningSecret(
            configuration["AUTH_JWT_PREVIOUS_SIGNING_KEY"],
            signingSecret,
            context.HostingEnvironment.IsProduction(),
            configuration["AUTH_MODE"]);
        var jwtIssuer = configuration["AUTH_JWT_ISSUER"] ?? "certigo";
        var jwtAudience = configuration["AUTH_JWT_AUDIENCE"] ?? "certigo";

        services.AddSingleton<ITokenValidator>(sp =>
        {
            // The local email/password validator is always first; whichever
            // environment validator follows is the fallback. The Dev validator
            // accepts ANY token, so it can only ever be the last link in the chain.
            var validators = new List<ITokenValidator>
            {
                new LocalJwtTokenValidator(
                    signingSecret, jwtIssuer, jwtAudience,
                    sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<LocalJwtTokenValidator>>(),
                    previousSigningSecret)
            };

            // Hard production guard: the dev validator accepts any bearer token as a
            // user id, so it can never be wired in production (even if AUTH_MODE=dev
            // leaks into config). The decision is a pure, unit-tested function.
            var useDev = AuthValidatorSelection.ShouldUseDevValidator(
                configuration["AUTH_MODE"],
                context.HostingEnvironment.IsProduction(),
                configuration["AUTH_ALLOW_DEV"]);
            if (useDev)
            {
                validators.Add(new DevTokenValidator());
            }
            else
            {
                // Only add Entra when it is actually configured; its ctor throws on
                // empty authority/audience, which would otherwise break local runs
                // that rely solely on email/password.
                var authority = configuration["ENTRA_AUTHORITY"];
                var audience = configuration["ENTRA_AUDIENCE"];
                if (!string.IsNullOrWhiteSpace(authority) && !string.IsNullOrWhiteSpace(audience))
                {
                    validators.Add(new EntraTokenValidator(
                        authority, audience,
                        sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<EntraTokenValidator>>()));
                }
            }

            return new CompositeTokenValidator(validators);
        });

        services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
        services.AddSingleton<ITokenIssuer>(_ => new JwtTokenIssuer(
            signingSecret,
            jwtIssuer,
            jwtAudience,
            previousSigningSecret: previousSigningSecret));
        services.AddScoped<IUserCredentialRepository, CosmosUserCredentialRepository>();

        // Email verification for email/password accounts. Non-blocking: the default
        // binding is a logging no-op so sign-up works with no provider configured;
        // a real Azure Communication Services sender is wired only when the ACS
        // settings are present (endpoint+sender for managed identity, or a
        // connection string). EMAIL_VERIFY_BASE_URL is the public URL of the GET
        // verify endpoint; empty is tolerated (the link is still logged/emailed).
        var verifyBaseUrl = configuration["EMAIL_VERIFY_BASE_URL"] ?? string.Empty;
        var verifyTtlHours = int.TryParse(configuration["EMAIL_VERIFY_TOKEN_TTL_HOURS"], out var ttl) && ttl > 0 ? ttl : 24;
        services.AddSingleton(new AuthEmailOptions(verifyBaseUrl, TimeSpan.FromHours(verifyTtlHours)));

        var acsConnectionString = configuration["ACS_EMAIL_CONNECTION_STRING"];
        var acsEndpoint = configuration["ACS_EMAIL_ENDPOINT"];
        var acsSender = configuration["ACS_EMAIL_SENDER"];
        if (!string.IsNullOrWhiteSpace(acsSender)
            && (!string.IsNullOrWhiteSpace(acsConnectionString) || !string.IsNullOrWhiteSpace(acsEndpoint)))
        {
            services.AddSingleton<IEmailSender>(sp =>
            {
                var client = !string.IsNullOrWhiteSpace(acsConnectionString)
                    ? new EmailClient(acsConnectionString)
                    : new EmailClient(new Uri(acsEndpoint!), sp.GetRequiredService<TokenCredential>());
                return new AzureCommunicationEmailSender(
                    client,
                    acsSender!,
                    sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<AzureCommunicationEmailSender>>());
            });
        }
        else
        {
            services.AddSingleton<IEmailSender, LoggingEmailSender>();
        }

        // One AuthService per scope, exposed under both its interfaces so the auth
        // endpoints and the verify/resend endpoints share the same instance.
        services.AddScoped<AuthService>();
        services.AddScoped<IAuthService>(sp => sp.GetRequiredService<AuthService>());
        services.AddScoped<IEmailVerificationService>(sp => sp.GetRequiredService<AuthService>());

        services.AddScoped<IUserContext, FunctionUserContext>();
        services.AddSingleton<IClock, SystemClock>();
        services.AddScoped<IUserRepository, CosmosUserRepository>();
        services.AddScoped<IContentRepository, CosmosContentRepository>();
        services.AddScoped<IProgressRepository, CosmosProgressRepository>();
        services.AddScoped<IAttemptRepository, CosmosAttemptRepository>();
        services.AddScoped<IExamAttemptRepository, CosmosExamAttemptRepository>();
        services.AddScoped<IExamRepository, CosmosExamRepository>();
        services.AddScoped<IEventRepository, CosmosEventRepository>();
        services.AddScoped<ILeaderboardRepository, CosmosLeaderboardRepository>();
        services.AddScoped<IPurchaseRepository, CosmosPurchaseRepository>();
        services.AddScoped<IEconomyOperationRepository, CosmosEconomyOperationRepository>();
        services.AddScoped<IFriendRepository, CosmosFriendRepository>();
        services.AddScoped<ILearnerModelRepository, CosmosLearnerModelRepository>();
        services.AddSingleton<ITutorLlmTelemetry, NullTutorLlmTelemetry>();
        var tutorLlmEnabled = string.Equals(configuration["TUTOR_LLM_ENABLED"], "true", StringComparison.OrdinalIgnoreCase);
        if (tutorLlmEnabled)
        {
            var tutorLlmOptions = TutorLlmConfiguration.FromConfiguration(configuration);
            services.AddSingleton(tutorLlmOptions);
            services.AddHttpClient("TutorLlm", client => client.Timeout = TimeSpan.FromSeconds(20));
            services.AddSingleton<ITutorLlmTelemetry, ApplicationInsightsTutorLlmTelemetry>();
            services.AddSingleton<ITutorCompletion>(sp => new AzureOpenAiTutorCompletion(
                sp.GetRequiredService<IHttpClientFactory>().CreateClient("TutorLlm"),
                sp.GetRequiredService<TokenCredential>(),
                sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<AzureOpenAiTutorCompletion>>(),
                sp.GetRequiredService<TutorLlmOptions>()));
        }
        else
        {
            services.AddSingleton<ITutorCompletion, NullTutorCompletion>();
        }
        services.AddScoped<IUserService, UserService>();
        services.AddScoped<IContentService, ContentService>();
        services.AddScoped<IQuizService, QuizService>();
        services.AddScoped<ILeaderboardService, LeaderboardService>();
        services.AddScoped<IPathService, PathService>();
        services.AddScoped<IRecommendationService, RecommendationService>();
        services.AddScoped<IShopService, ShopService>();
        services.AddScoped<IQuestService, QuestService>();
        services.AddScoped<IAchievementService, AchievementService>();
        services.AddScoped<IShareCardService, ShareCardService>();
        services.AddScoped<IFriendService, FriendService>();
        services.AddScoped<IStreakRepairService, StreakRepairService>();
        services.AddScoped<IExamService, ExamService>();
        services.AddScoped<ITutorService, TutorService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<ISeasonService, SeasonService>();
    })
    .Build();

host.Run();

public sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}

internal static class TutorLlmConfiguration
{
    private const string DefaultApiVersion = "2024-10-21";
    private const int DefaultMaxOutputTokens = 400;

    public static TutorLlmOptions FromConfiguration(IConfiguration configuration)
    {
        var endpointRaw = configuration["TUTOR_LLM_ENDPOINT"];
        if (string.IsNullOrWhiteSpace(endpointRaw)
            || !Uri.TryCreate(endpointRaw, UriKind.Absolute, out var endpoint))
        {
            throw new InvalidOperationException(
                "TUTOR_LLM_ENDPOINT must be an absolute Azure OpenAI resource endpoint when TUTOR_LLM_ENABLED=true.");
        }

        var deployment = configuration["TUTOR_LLM_DEPLOYMENT"];
        if (string.IsNullOrWhiteSpace(deployment))
        {
            throw new InvalidOperationException(
                "TUTOR_LLM_DEPLOYMENT is required when TUTOR_LLM_ENABLED=true.");
        }

        var apiSurface = ParseApiSurface(configuration["TUTOR_LLM_API_SURFACE"]);
        var apiVersion = configuration["TUTOR_LLM_API_VERSION"];
        var apiKey = configuration["TUTOR_LLM_API_KEY"];
        var maxOutputTokens = DefaultMaxOutputTokens;
        var maxOutputTokensRaw = configuration["TUTOR_LLM_MAX_OUTPUT_TOKENS"];
        if (!string.IsNullOrWhiteSpace(maxOutputTokensRaw)
            && (!int.TryParse(maxOutputTokensRaw, out maxOutputTokens) || maxOutputTokens <= 0))
        {
            throw new InvalidOperationException(
                "TUTOR_LLM_MAX_OUTPUT_TOKENS must be a positive integer when provided.");
        }

        // The v1 (Microsoft Foundry) surface ignores api-version; only the classic surface uses it.
        var resolvedApiVersion = apiSurface == TutorLlmApiSurface.AzureClassic
            ? (string.IsNullOrWhiteSpace(apiVersion) ? DefaultApiVersion : apiVersion)
            : (string.IsNullOrWhiteSpace(apiVersion) ? null : apiVersion);

        return new TutorLlmOptions(
            NormalizeEndpoint(endpoint),
            deployment,
            resolvedApiVersion,
            string.IsNullOrWhiteSpace(apiKey) ? null : apiKey,
            maxOutputTokens,
            apiSurface);
    }

    private static TutorLlmApiSurface ParseApiSurface(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return TutorLlmApiSurface.V1;
        }

        return raw.Trim().ToLowerInvariant() switch
        {
            "v1" or "foundry" => TutorLlmApiSurface.V1,
            "classic" or "azure" => TutorLlmApiSurface.AzureClassic,
            _ => throw new InvalidOperationException(
                "TUTOR_LLM_API_SURFACE must be 'v1' (Microsoft Foundry, default) or 'classic' (Azure OpenAI deployments path).")
        };
    }

    private static Uri NormalizeEndpoint(Uri endpoint)
    {
        var builder = new UriBuilder(endpoint);
        var path = builder.Path.TrimEnd('/');
        builder.Path = string.IsNullOrEmpty(path) ? "/" : $"{path}/";
        return builder.Uri;
    }
}
