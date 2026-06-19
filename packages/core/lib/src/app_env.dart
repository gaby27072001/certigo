/// Compile-time environment configuration, injected via `--dart-define`.
///
/// Never hard-code endpoints or client ids. Build flavors pass values:
/// ```
/// flutter run --dart-define=MICROLINGO_ENV=dev \
///   --dart-define=API_BASE_URL=https://dev.api.microlingo.app \
///   --dart-define=ENTRA_CLIENT_ID=... --dart-define=ENTRA_AUTHORITY=...
/// ```
enum AppFlavor { dev, staging, prod }

class AppEnv {
  const AppEnv._();

  static const String _rawEnv = String.fromEnvironment('MICROLINGO_ENV', defaultValue: 'dev');

  static AppFlavor get flavor => switch (_rawEnv) {
        'prod' => AppFlavor.prod,
        'staging' => AppFlavor.staging,
        _ => AppFlavor.dev,
      };

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev.api.microlingo.app/api',
  );

  /// Microsoft Entra External ID — public client configuration.
  static const String entraClientId = String.fromEnvironment('ENTRA_CLIENT_ID', defaultValue: '');
  static const String entraAuthority = String.fromEnvironment('ENTRA_AUTHORITY', defaultValue: '');
  static const String entraRedirectUri = String.fromEnvironment(
    'ENTRA_REDIRECT_URI',
    defaultValue: 'microlingo://auth',
  );

  static const List<String> entraScopes = <String>[
    'openid',
    'profile',
    'offline_access',
  ];

  static bool get isProd => flavor == AppFlavor.prod;
  static bool get analyticsEnabled => isProd || flavor == AppFlavor.staging;
}
