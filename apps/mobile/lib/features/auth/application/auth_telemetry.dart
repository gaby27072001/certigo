import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';

/// Méthode de connexion mesurée (label non sensible, jamais l'e-mail réel).
enum AuthMethod { email, register, microsoft, google, apple, restore, refresh }

extension AuthMethodX on AuthMethod {
  String get label => switch (this) {
        AuthMethod.email => 'email',
        AuthMethod.register => 'register',
        AuthMethod.microsoft => 'microsoft',
        AuthMethod.google => 'google',
        AuthMethod.apple => 'apple',
        AuthMethod.restore => 'restore',
        AuthMethod.refresh => 'refresh',
      };

  static AuthMethod fromProvider(AuthProvider provider) => switch (provider) {
        AuthProvider.microsoft => AuthMethod.microsoft,
        AuthProvider.google => AuthMethod.google,
        AuthProvider.apple => AuthMethod.apple,
        AuthProvider.email => AuthMethod.email,
      };
}

/// Abstraction d'événements d'authentification.
///
/// Remplace l'instrumentation `[LOGIN-DBG]` (bruyante, temporaire) par une API
/// stable et **sans donnée sensible** : on ne transmet jamais de jeton, mot de
/// passe ou e-mail — uniquement la méthode (label), la cause normalisée d'un
/// échec, et un timing bout-en-bout. Un vrai puits (Application Insights) pourra
/// implémenter cette interface sans toucher au reste du code d'auth.
///
/// KPI cibles dérivables de ces événements (voir docs/CONFIG_AUTH.md) :
/// - taux de succès login/inscription par méthode (success / start) ≥ 98 % ;
/// - latence médiane de connexion (durationMs des succès) ≤ 3 s ;
/// - taux d'abandon (cancelled / start) ;
/// - répartition des échecs par [AuthFailureCause].
abstract interface class AuthTelemetry {
  /// Début d'une tentative de connexion/inscription.
  void authStart(AuthMethod method);

  /// Succès, avec la durée bout-en-bout mesurée par le contrôleur.
  void authSuccess(AuthMethod method, {int? durationMs});

  /// Échec, avec la cause normalisée et la durée jusqu'à l'échec.
  void authFailure(AuthMethod method, AuthFailureCause cause, {int? durationMs});
}

/// Implémentation neutre (aucun effet). Défaut en prod tant qu'aucun puits réel
/// n'est branché : garantit qu'aucune donnée ne fuit par défaut.
class NoopAuthTelemetry implements AuthTelemetry {
  const NoopAuthTelemetry();

  @override
  void authStart(AuthMethod method) {}

  @override
  void authSuccess(AuthMethod method, {int? durationMs}) {}

  @override
  void authFailure(AuthMethod method, AuthFailureCause cause, {int? durationMs}) {}
}

/// Implémentation de développement : journalise via [debugPrint] (remplace
/// proprement `[LOGIN-DBG]`). N'émet rien en release (debugPrint est no-op).
class DebugAuthTelemetry implements AuthTelemetry {
  const DebugAuthTelemetry();

  @override
  void authStart(AuthMethod method) => debugPrint('[auth] start method=${method.label}');

  @override
  void authSuccess(AuthMethod method, {int? durationMs}) =>
      debugPrint('[auth] success method=${method.label} durationMs=${durationMs ?? '-'}');

  @override
  void authFailure(AuthMethod method, AuthFailureCause cause, {int? durationMs}) => debugPrint(
        '[auth] failure method=${method.label} cause=${cause.name} durationMs=${durationMs ?? '-'}',
      );
}

/// Puits de télémétrie d'auth injecté dans le contrôleur.
///
/// Debug par défaut en développement (utile localement), neutre en release
/// (aucune fuite tant qu'un vrai puits n'est pas câblé). Surchargeable dans les
/// tests par un faux vérifiable.
final authTelemetryProvider = Provider<AuthTelemetry>(
  (Ref ref) => kDebugMode ? const DebugAuthTelemetry() : const NoopAuthTelemetry(),
);
