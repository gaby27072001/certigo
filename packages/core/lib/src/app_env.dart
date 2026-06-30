/// Compile-time environment configuration, injected via `--dart-define`.
///
/// Les *secrets* (client secrets, clés API) ne doivent JAMAIS figurer ici : ils
/// passent par `--dart-define` au build ou par le Key Vault côté backend. En
/// revanche les identifiants OIDC *publics* (client id public, authority CIAM,
/// redirect URI) peuvent avoir des défauts committés ci-dessous. Les flavors de
/// build surchargent ces valeurs :
/// ```
/// flutter run --dart-define=CERTIGO_ENV=dev \
///   --dart-define=API_BASE_URL=https://dev.api.certigo.app \
///   --dart-define=ENTRA_CLIENT_ID=... --dart-define=ENTRA_AUTHORITY=...
/// ```
enum AppFlavor { dev, staging, prod }

class AppEnv {
  const AppEnv._();

  static const String _rawEnv = String.fromEnvironment('CERTIGO_ENV', defaultValue: 'dev');

  static AppFlavor get flavor => switch (_rawEnv) {
        'prod' => AppFlavor.prod,
        'staging' => AppFlavor.staging,
        _ => AppFlavor.dev,
      };

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev.api.certigo.app/api',
  );

  /// Dev/staging bearer token sent until Entra External ID is wired. The backend
  /// dev token validator resolves any non-empty value to a stable userId, so the
  /// app works end-to-end against a dev API. Production must inject a real Entra
  /// access token (see [tokenProvider]) and never relies on this.
  static const String devAuthToken = String.fromEnvironment('DEV_AUTH_TOKEN', defaultValue: 'dev');

  /// Microsoft Entra External ID — public client configuration.
  ///
  /// Les défauts pointent vers le locataire CIAM Certigo (`certigoapp`). Ce sont
  /// des identifiants OIDC *publics* (visibles dans chaque requête d'autorisation
  /// et la redirection navigateur), pas des secrets — d'où leur présence ici pour
  /// que le social sign-in fonctionne out-of-the-box. Surchargeables via
  /// `--dart-define=ENTRA_CLIENT_ID=…` / `ENTRA_AUTHORITY=…` pour cibler un autre
  /// locataire (staging/prod).
  static const String entraClientId = String.fromEnvironment(
    'ENTRA_CLIENT_ID',
    defaultValue: '4d1f1075-7bc5-4764-947b-701435a85f8c',
  );
  static const String entraAuthority = String.fromEnvironment(
    'ENTRA_AUTHORITY',
    defaultValue: 'https://certigoapp.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0',
  );
  static const String entraRedirectUri = String.fromEnvironment(
    'ENTRA_REDIRECT_URI',
    defaultValue: 'certigo://auth',
  );

  static const List<String> entraScopes = <String>[
    'openid',
    'profile',
    'email', // needed for the email claim on Microsoft accounts
    'offline_access',
  ];

  /// Scope d'API protégée (ex. `api://<api-client-id>/.default`). Quand il est
  /// renseigné, Entra émet un access_token dont l'`aud` correspond à
  /// `ENTRA_AUDIENCE` côté backend, ce qui permet de l'envoyer en Bearer.
  static const String entraApiScope = String.fromEnvironment('ENTRA_API_SCOPE', defaultValue: '');

  /// Indices de domaine (`domain_hint`) pour pré-orienter Entra vers le bon
  /// fournisseur fédéré. Configurables car le nom exact du fournisseur Google /
  /// Apple dépend du paramétrage du locataire externe.
  ///
  /// Pour Microsoft : `microsoft.com` achemine vers le fournisseur Microsoft
  /// Account configuré dans le locataire CIAM, qui accepte à la fois les
  /// comptes personnels MSA (outlook.com, hotmail.com…) ET les comptes
  /// professionnels Azure AD (y compris les comptes @microsoft.com des employés
  /// Microsoft). Laisser vide revient à afficher l'écran CIAM générique sans
  /// bouton Microsoft visible.
  static const String microsoftDomainHint = String.fromEnvironment(
    'ENTRA_DOMAIN_HINT_MICROSOFT',
    defaultValue: 'microsoft.com',
  );
  static const String googleDomainHint = String.fromEnvironment(
    'ENTRA_DOMAIN_HINT_GOOGLE',
    defaultValue: 'google.com',
  );
  static const String appleDomainHint = String.fromEnvironment(
    'ENTRA_DOMAIN_HINT_APPLE',
    defaultValue: 'apple.com',
  );

  /// Vrai quand Entra External ID est réellement configuré : l'app présente
  /// alors le vrai écran de connexion multi-fournisseurs.
  static bool get entraConfigured => entraClientId.isNotEmpty && entraAuthority.isNotEmpty;

  /// Force l'affichage de l'écran de connexion même sans Entra configuré, pour
  /// prévisualiser/tester l'UI en dev (`--dart-define=FORCE_AUTH_UI=true`).
  static const bool forceAuthUi = bool.fromEnvironment('FORCE_AUTH_UI', defaultValue: false);

  static bool get isProd => flavor == AppFlavor.prod;
  static bool get analyticsEnabled => isProd || flavor == AppFlavor.staging;
}
