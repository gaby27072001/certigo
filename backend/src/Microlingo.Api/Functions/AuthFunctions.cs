using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

/// Anonymous email/password endpoints. These are the only write endpoints that
/// bypass the bearer-token middleware (see <c>JwtAuthMiddleware.AnonymousFunctions</c>);
/// they hand back locally-signed tokens the rest of the API then requires.
public sealed class AuthFunctions(IAuthService auth)
{
    [Function("Register")]
    public async Task<HttpResponseData> Register(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth/register")] HttpRequestData request,
        FunctionContext context)
    {
        var body = await request.ReadJsonAsync<RegisterRequest>(context.CancellationToken);
        if (!AuthRules.IsValidEmail(body.Email))
        {
            throw new BadRequestException("Adresse e-mail invalide.");
        }

        if (!AuthRules.IsValidPassword(body.Password))
        {
            throw new BadRequestException($"Le mot de passe doit contenir au moins {AuthRules.MinPasswordLength} caractères.");
        }

        var result = await auth.RegisterAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, System.Net.HttpStatusCode.Created, context.CancellationToken);
    }

    [Function("Login")]
    public async Task<HttpResponseData> Login(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth/login")] HttpRequestData request,
        FunctionContext context)
    {
        var body = await request.ReadJsonAsync<LoginRequest>(context.CancellationToken);
        if (string.IsNullOrWhiteSpace(body.Email) || string.IsNullOrEmpty(body.Password))
        {
            throw new BadRequestException("E-mail et mot de passe sont requis.");
        }

        var result = await auth.LoginAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("RefreshToken")]
    public async Task<HttpResponseData> RefreshToken(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth/refresh")] HttpRequestData request,
        FunctionContext context)
    {
        var body = await request.ReadJsonAsync<RefreshTokenRequest>(context.CancellationToken);
        if (string.IsNullOrWhiteSpace(body.RefreshToken))
        {
            throw new BadRequestException("Le jeton de rafraîchissement est requis.");
        }

        var result = await auth.RefreshAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
