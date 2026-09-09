using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

/// Anonymous email/password endpoints. These are the only write endpoints that
/// bypass the bearer-token middleware (see <c>JwtAuthMiddleware.AnonymousFunctions</c>);
/// they hand back locally-signed tokens the rest of the API then requires.
public sealed class AuthFunctions(
    IAuthService auth,
    IEmailVerificationService? verification = null,
    IPasswordResetService? passwordReset = null)
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

    [Function("VerifyEmail")]
    public async Task<HttpResponseData> VerifyEmail(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "auth/verify-email")] HttpRequestData request,
        FunctionContext context)
    {
        var service = verification ?? throw new InvalidOperationException("Email verification service is not configured.");
        var code = ReadQueryParam(request, "code");
        var result = await service.VerifyAsync(code ?? string.Empty, context.CancellationToken);

        // Rendered in a browser (the learner clicked the link in their inbox), so
        // return a small self-contained HTML page rather than JSON.
        var response = request.CreateResponse(result.Success
            ? System.Net.HttpStatusCode.OK
            : System.Net.HttpStatusCode.BadRequest);
        response.Headers.Add("Content-Type", "text/html; charset=utf-8");
        await response.WriteStringAsync(VerificationHtml.Page(result), context.CancellationToken);
        return response;
    }

    [Function("ResendVerification")]
    public async Task<HttpResponseData> ResendVerification(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth/resend-verification")] HttpRequestData request,
        FunctionContext context)
    {
        var service = verification ?? throw new InvalidOperationException("Email verification service is not configured.");
        var body = await request.ReadJsonAsync<ResendVerificationRequest>(context.CancellationToken);
        await service.ResendAsync(body.Email ?? string.Empty, context.CancellationToken);

        // Always the same generic answer (no account enumeration).
        return await request.JsonAsync(
            new { message = "Si un compte existe pour cette adresse, un e-mail de vérification vient d'être envoyé." },
            cancellationToken: context.CancellationToken);
    }

    [Function("RequestPasswordReset")]
    public async Task<HttpResponseData> RequestPasswordReset(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth/request-password-reset")] HttpRequestData request,
        FunctionContext context)
    {
        var service = passwordReset ?? throw new InvalidOperationException("Password reset service is not configured.");
        var body = await request.ReadJsonAsync<PasswordResetRequestDto>(context.CancellationToken);
        await service.RequestAsync(body.Email ?? string.Empty, context.CancellationToken);

        // Always the same generic answer, byte-for-byte, whether an account
        // exists or not (anti-enumeration). Mirrors ResendVerification.
        return await request.JsonAsync(
            new { message = "Si un compte existe pour cette adresse, un e-mail de réinitialisation vient d'être envoyé." },
            cancellationToken: context.CancellationToken);
    }

    [Function("ResetPassword")]
    public async Task<HttpResponseData> ResetPassword(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth/reset-password")] HttpRequestData request,
        FunctionContext context)
    {
        var service = passwordReset ?? throw new InvalidOperationException("Password reset service is not configured.");
        var body = await request.ReadJsonAsync<PasswordResetConfirmRequest>(context.CancellationToken);
        var result = await service.ResetAsync(
            body.Code ?? string.Empty,
            body.NewPassword ?? string.Empty,
            context.CancellationToken);

        // Called from the mobile client (not a browser click-through), so answer
        // in JSON. Failures are 400 with the generic message; the client shows
        // "Lien expiré ou invalide" without distinguishing failure modes.
        return await request.JsonAsync(
            new { success = result.Success, message = result.Message },
            result.Success ? System.Net.HttpStatusCode.OK : System.Net.HttpStatusCode.BadRequest,
            context.CancellationToken);
    }

    private static string? ReadQueryParam(HttpRequestData request, string key)
    {
        var query = request.Url.Query;
        if (string.IsNullOrEmpty(query))
        {
            return null;
        }

        foreach (var pair in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var separator = pair.IndexOf('=');
            if (separator > 0 && pair[..separator] == key)
            {
                return Uri.UnescapeDataString(pair[(separator + 1)..]);
            }
        }

        return null;
    }
}

/// Minimal, self-contained confirmation page rendered by the GET verify endpoint.
internal static class VerificationHtml
{
    public static string Page(EmailVerificationResult result)
    {
        var icon = result.Success ? "✅" : "⚠️";
        var title = result.Success ? "E-mail confirmé" : "Vérification impossible";
        var message = System.Net.WebUtility.HtmlEncode(result.Message);
        return
            "<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\">" +
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" +
            $"<title>{title} — Certigo</title></head>" +
            "<body style=\"font-family:Segoe UI,Arial,sans-serif;background:#f5f5f7;margin:0;padding:0\">" +
            "<div style=\"max-width:440px;margin:12vh auto;background:#fff;border-radius:16px;padding:40px 32px;text-align:center;box-shadow:0 10px 40px rgba(0,0,0,.08)\">" +
            $"<div style=\"font-size:48px\">{icon}</div>" +
            $"<h1 style=\"font-size:22px;color:#1b1b1f;margin:16px 0 8px\">{title}</h1>" +
            $"<p style=\"color:#4b5563;font-size:15px;line-height:1.5\">{message}</p>" +
            "<p style=\"color:#9ca3af;font-size:13px;margin-top:24px\">Certigo</p>" +
            "</div></body></html>";
    }
}
