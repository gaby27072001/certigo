import 'release_profile.dart';

/// Compile-time environment configuration, injected via `--dart-define`.
///
/// Never hard-code endpoints or client ids. Build flavors pass values:
/// ```
/// flutter run --dart-define=CERTIGO_ENV=dev \
///   --dart-define=API_BASE_URL=https://api.example.invalid \
///   --dart-define=ENTRA_CLIENT_ID=... --dart-define=ENTRA_AUTHORITY=...
/// ```
enum AppFlavor { dev, staging, prod }

class AppEnv {
  const AppEnv._();

  static const String _rawEnv = String.fromEnvironment('CERTIGO_ENV', defaultValue: 'dev');
  static const String releaseProfileName = String.fromEnvironment(
    'CERTIGO_RELEASE_PROFILE',
    defaultValue: '',
  );

  static AppFlavor get flavor => switch (_rawEnv) {
        'prod' => AppFlavor.prod,
        'staging' => AppFlavor.staging,
        _ => AppFlavor.dev,
      };

  /// URL du backend dev, servie **uniquement** en repli local (voir [apiBaseUrl]).
  /// Exposée comme constante nommée pour que [validate] puisse détecter — et
  /// interdire — sa présence dans un build prod/staging (fuite dangereuse d'un
  /// endpoint dev en production).
  static const String devApiBaseUrl =
      'https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api';

  // Fallback utilisé uniquement quand aucun `--dart-define=API_BASE_URL` n'est
  // fourni (ex. `flutter run` local sans flag). Tous les builds officiels
  // (CI release, Codemagic) injectent l'URL réelle et n'atteignent jamais ce
  // défaut. Pointe vers le backend dev joignable plutôt qu'un host mort.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: devApiBaseUrl,
  );

  /// Dev/staging bearer token sent until Entra External ID is wired. The backend
  /// dev token validator resolves any non-empty value to a stable userId, so the
  /// app works end-to-end against a dev API. Production must inject a real Entra
  /// access token (see [tokenProvider]) and never relies on this.
  static const String devAuthToken = String.fromEnvironment('DEV_AUTH_TOKEN', defaultValue: 'dev');

  /// Microsoft Entra External ID — public client configuration.
  static const String entraClientId = String.fromEnvironment('ENTRA_CLIENT_ID', defaultValue: '');
  static const String entraAuthority = String.fromEnvironment('ENTRA_AUTHORITY', defaultValue: '');

  /// URI de redirection OIDC de l'app.
  ///
  /// Le **slash final** (`certigo://auth/`) est **requis**. Le SDK AppAuth iOS
  /// valide l'URL de redirection avant de décider s'il doit traiter le callback ;
  /// avec Azure/CIAM (Entra External ID) cette validation échoue pour un redirect
  /// **sans** slash final → la connexion sociale iOS « hang » : le navigateur se
  /// ferme après la page de confirmation CIAM mais `authorize()` ne reçoit jamais
  /// le code (le callback n'est pas reconnu). Android et le login e-mail ne sont
  /// pas affectés. Référence : FAQ officielle `flutter_appauth`.
  ///
  /// Le schéma reste `certigo` (voir [redirectScheme]) : seul le chemin gagne un
  /// slash, donc les déclarations natives (Info.plist / build.gradle) restent
  /// valables. Cette valeur exacte (`certigo://auth/`) doit être enregistrée dans
  /// l'app registration Entra (plateforme « Applications de bureau et mobiles »).
  static const String entraRedirectUri = String.fromEnvironment(
    'ENTRA_REDIRECT_URI',
    defaultValue: 'certigo://auth/',
  );

  /// Schéma d'URI natif câblé en dur côté iOS (`Info.plist` CFBundleURLSchemes)
  /// et Android (`build.gradle` `appAuthRedirectScheme`). [entraRedirectUri]
  /// **doit** utiliser ce schéma, sinon le callback OIDC n'est jamais capté par
  /// l'app (connexion sociale qui « ne revient jamais »). Vérifié par [validate].
  static const String redirectScheme = 'certigo';

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

  /// Keeps account deletion unavailable until the destructive Cosmos gate has
  /// passed. This operational kill switch remains independent from product
  /// release profiles so a `full` build cannot bypass the safety contract.
  static const bool accountDeletionEnabled = bool.fromEnvironment(
    'ACCOUNT_DELETION_ENABLED',
    defaultValue: false,
  );

  static const CapabilityRuntimePolicy capabilityRuntimePolicy = CapabilityRuntimePolicy(
    accountDeletionEnabled: accountDeletionEnabled,
  );

  /// Assouplit [validate] : quand `true`, l'absence **totale** de configuration
  /// Entra (client id + autorité vides) devient un simple avertissement au lieu
  /// d'une erreur bloquante, même en prod. À n'utiliser que pour un build
  /// **e-mail/mot de passe uniquement** assumé (`--dart-define=ENTRA_OPTIONAL=true`).
  /// Par défaut `false` : un build prod/staging DOIT fournir Entra pour offrir
  /// les 4 méthodes de connexion.
  static const bool entraOptional = bool.fromEnvironment('ENTRA_OPTIONAL', defaultValue: false);

  static bool get isProd => flavor == AppFlavor.prod;
  static bool get analyticsEnabled => isProd || flavor == AppFlavor.staging;

  /// Les flavors « stricts » (prod/staging) exigent une configuration complète
  /// et valide : tout défaut de config y est **bloquant** (et non un simple
  /// avertissement). Le garde-fou de démarrage bloque le lancement si invalide.
  static bool get isStrictFlavor => flavor == AppFlavor.prod || flavor == AppFlavor.staging;

  static ReleaseProfileResolution get releaseProfileResolution =>
      ReleaseProfile.resolve(releaseProfileName);

  /// Valide la configuration compile-time (`--dart-define`) réelle.
  ///
  /// Délègue à [validateConfig] avec les constantes ci-dessus. Le garde-fou de
  /// démarrage (`bootstrap`) l'appelle et **échoue fort** en prod/staging si
  /// [AppConfigReport.isValid] est faux, plutôt que de démarrer silencieusement
  /// sur une config dev/incohérente.
  static AppConfigReport validate() => validateConfig(
        flavor: flavor,
        apiBaseUrl: apiBaseUrl,
        entraClientId: entraClientId,
        entraAuthority: entraAuthority,
        entraRedirectUri: entraRedirectUri,
        entraApiScope: entraApiScope,
        entraOptional: entraOptional,
        releaseProfileName: releaseProfileName,
      );

  /// Cœur de validation : **pur et sans I/O**, ne lit aucune constante globale.
  /// Isolé ainsi pour être testable unitairement avec des valeurs arbitraires
  /// (les tests ne pouvant pas injecter de `--dart-define`). [validate] fournit
  /// les valeurs compile-time réelles.
  static AppConfigReport validateConfig({
    required AppFlavor flavor,
    required String apiBaseUrl,
    required String entraClientId,
    required String entraAuthority,
    required String entraRedirectUri,
    required String entraApiScope,
    bool entraOptional = false,
    String releaseProfileName = 'full',
  }) {
    final bool strictFlavor = flavor == AppFlavor.prod || flavor == AppFlavor.staging;
    final List<AppConfigIssue> issues = <AppConfigIssue>[];
    final AppConfigSeverity strict =
        strictFlavor ? AppConfigSeverity.error : AppConfigSeverity.warning;

    final ReleaseProfileResolution release = ReleaseProfile.resolve(releaseProfileName);
    if (!release.isValid) {
      issues.add(
        AppConfigIssue(AppConfigSeverity.error, 'CERTIGO_RELEASE_PROFILE', release.issue!.message),
      );
    }

    // --- API_BASE_URL ---
    if (apiBaseUrl.trim().isEmpty) {
      issues.add(
        const AppConfigIssue(
          AppConfigSeverity.error,
          'API_BASE_URL',
          'URL de l\'API absente : le login e-mail échouera (« Pas de connexion »). '
              'Injectez --dart-define=API_BASE_URL=https://<host>/api.',
        ),
      );
    } else {
      if (strictFlavor && apiBaseUrl == devApiBaseUrl) {
        issues.add(
          const AppConfigIssue(
            AppConfigSeverity.error,
            'API_BASE_URL',
            'Build prod/staging pointant sur l\'API DEV par défaut. '
                'Injectez l\'URL réelle via --dart-define=API_BASE_URL.',
          ),
        );
      }
      if (strictFlavor && !apiBaseUrl.startsWith('https://')) {
        issues.add(
          AppConfigIssue(
            AppConfigSeverity.error,
            'API_BASE_URL',
            'L\'API doit être servie en HTTPS en prod/staging (reçu : $apiBaseUrl).',
          ),
        );
      }
    }

    // --- Entra : cohérence client_id / autorité ---
    final bool hasClientId = entraClientId.trim().isNotEmpty;
    final bool hasAuthority = entraAuthority.trim().isNotEmpty;
    if (hasClientId != hasAuthority) {
      // Config partielle : toujours un bug (bouton social présent qui échoue,
      // ou disparition silencieuse selon l'ordre de lecture).
      issues.add(
        AppConfigIssue(
          AppConfigSeverity.error,
          hasClientId ? 'ENTRA_AUTHORITY' : 'ENTRA_CLIENT_ID',
          'Configuration Entra incomplète : ENTRA_CLIENT_ID et ENTRA_AUTHORITY '
          'doivent être fournis ensemble (l\'un est renseigné, l\'autre vide).',
        ),
      );
    } else if (!hasClientId) {
      // Entra totalement absent : bloquant en prod (sauf opt-in e-mail seul).
      final AppConfigSeverity sev =
          (strictFlavor && !entraOptional) ? AppConfigSeverity.error : AppConfigSeverity.warning;
      issues.add(
        AppConfigIssue(
          sev,
          'ENTRA_CLIENT_ID',
          'Connexion sociale (Microsoft/Google/Apple) désactivée : ENTRA_CLIENT_ID '
              'et ENTRA_AUTHORITY absents. Renseignez-les, ou assumez un build '
              'e-mail uniquement avec --dart-define=ENTRA_OPTIONAL=true.',
        ),
      );
    }

    // --- Redirect URI : doit utiliser le schéma natif ---
    final Uri? redirect = Uri.tryParse(entraRedirectUri);
    if (redirect == null || redirect.scheme != redirectScheme) {
      // Schéma incohérent → le callback OIDC ne revient jamais dans l'app.
      // Bloquant dès qu'Entra est (au moins partiellement) configuré ou strict.
      final AppConfigSeverity sev =
          (hasClientId || hasAuthority || strictFlavor) ? strict : AppConfigSeverity.warning;
      issues.add(
        AppConfigIssue(
          sev,
          'ENTRA_REDIRECT_URI',
          'ENTRA_REDIRECT_URI ($entraRedirectUri) n\'utilise pas le schéma natif '
              '« $redirectScheme:// » déclaré dans Info.plist / build.gradle : le '
              'callback de connexion ne reviendra jamais dans l\'app.',
        ),
      );
    }

    // --- API scope : recommandé quand Entra est configuré (aud backend) ---
    if (hasClientId && hasAuthority && entraApiScope.trim().isEmpty) {
      issues.add(
        const AppConfigIssue(
          AppConfigSeverity.warning,
          'ENTRA_API_SCOPE',
          'ENTRA_API_SCOPE vide alors qu\'Entra est configuré : l\'access_token '
              'peut ne pas cibler l\'API (risque de 401). Renseignez '
              'api://<client-id>/... si le backend valide l\'audience.',
        ),
      );
    }

    return AppConfigReport(issues);
  }
}

/// Gravité d'un problème de configuration détecté par [AppEnv.validate].
enum AppConfigSeverity {
  /// Bloquant : en prod/staging le démarrage doit échouer fort.
  error,

  /// Non bloquant : signalé (log/écran dev) mais l'app peut démarrer.
  warning,
}

/// Un problème de configuration unitaire (clé concernée + message actionnable).
class AppConfigIssue {
  const AppConfigIssue(this.severity, this.key, this.message);

  final AppConfigSeverity severity;
  final String key;
  final String message;

  @override
  String toString() => '[${severity.name.toUpperCase()}] $key: $message';
}

/// Rapport agrégé de [AppEnv.validate] : erreurs bloquantes + avertissements.
class AppConfigReport {
  const AppConfigReport(this.issues);

  final List<AppConfigIssue> issues;

  List<AppConfigIssue> get errors =>
      issues.where((AppConfigIssue i) => i.severity == AppConfigSeverity.error).toList();

  List<AppConfigIssue> get warnings =>
      issues.where((AppConfigIssue i) => i.severity == AppConfigSeverity.warning).toList();

  /// Vrai quand aucune erreur bloquante n'a été trouvée (avertissements tolérés).
  bool get isValid => errors.isEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get hasReleaseProfileError =>
      errors.any((AppConfigIssue issue) => issue.key == 'CERTIGO_RELEASE_PROFILE');

  /// Résumé multi-lignes pour les logs et l'écran de config invalide.
  String describe() => issues.map((AppConfigIssue i) => '• $i').join('\n');
}
