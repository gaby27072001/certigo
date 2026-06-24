using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Core;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.ApplicationInsights;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microlingo.Api.Auth;
using Microlingo.Api.Middleware;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Services;
using Microlingo.Infrastructure.Ai;
using Microlingo.Infrastructure.Cosmos;
using Microlingo.Infrastructure.Identity;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults(worker =>
    {
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

        // Locally-issued JWT settings shared by the issuer and the local validator.
        // The signing key is mandatory in Production; a fixed dev key is used
        // elsewhere so the email/password flow works out of the box locally.
        var configuredSecret = configuration["AUTH_JWT_SIGNING_KEY"];
        var signingSecret = !string.IsNullOrWhiteSpace(configuredSecret)
            ? configuredSecret
            : context.HostingEnvironment.IsProduction()
                ? throw new InvalidOperationException(
                    "AUTH_JWT_SIGNING_KEY is required in Production to sign email/password tokens.")
                : "microlingo-dev-signing-key-change-me";
        var jwtIssuer = configuration["AUTH_JWT_ISSUER"] ?? "microlingo";
        var jwtAudience = configuration["AUTH_JWT_AUDIENCE"] ?? "microlingo";

        services.AddSingleton<ITokenValidator>(_ =>
        {
            // The local email/password validator is always first; whichever
            // environment validator follows is the fallback. The Dev validator
            // accepts ANY token, so it can only ever be the last link in the chain.
            var validators = new List<ITokenValidator>
            {
                new LocalJwtTokenValidator(signingSecret, jwtIssuer, jwtAudience)
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
                    validators.Add(new EntraTokenValidator(authority, audience));
                }
            }

            return new CompositeTokenValidator(validators);
        });

        services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
        services.AddSingleton<ITokenIssuer>(_ => new JwtTokenIssuer(signingSecret, jwtIssuer, jwtAudience));
        services.AddScoped<IUserCredentialRepository, CosmosUserCredentialRepository>();
        services.AddScoped<IAuthService, AuthService>();

        services.AddScoped<IUserContext, FunctionUserContext>();
        services.AddSingleton<IClock, SystemClock>();
        services.AddScoped<IUserRepository, CosmosUserRepository>();
        services.AddScoped<IContentRepository, CosmosContentRepository>();
        services.AddScoped<IProgressRepository, CosmosProgressRepository>();
        services.AddScoped<IAttemptRepository, CosmosAttemptRepository>();
        services.AddScoped<IExamAttemptRepository, CosmosExamAttemptRepository>();
        services.AddScoped<IEventRepository, CosmosEventRepository>();
        services.AddScoped<ILeaderboardRepository, CosmosLeaderboardRepository>();
        services.AddScoped<IPurchaseRepository, CosmosPurchaseRepository>();
        services.AddScoped<IFriendRepository, CosmosFriendRepository>();
        services.AddScoped<ILearnerModelRepository, CosmosLearnerModelRepository>();
        services.AddSingleton<ITutorCompletion, NullTutorCompletion>();
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
