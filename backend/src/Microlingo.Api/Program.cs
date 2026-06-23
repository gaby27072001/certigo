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

        services.AddSingleton<ITokenValidator>(_ =>
        {
            var authMode = configuration["AUTH_MODE"];
            if (string.Equals(authMode, "dev", StringComparison.OrdinalIgnoreCase))
            {
                return new DevTokenValidator();
            }

            return new EntraTokenValidator(
                configuration["ENTRA_AUTHORITY"] ?? string.Empty,
                configuration["ENTRA_AUDIENCE"] ?? string.Empty);
        });

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
    })
    .Build();

host.Run();

public sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
