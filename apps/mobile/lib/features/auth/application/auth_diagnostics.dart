import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Étape **tracée** du flux de connexion sociale (OIDC via Entra External ID).
///
/// Motivation (build de diagnostic iOS) : le callback `certigo://auth` peut ne
/// jamais revenir à `ASWebAuthenticationSession` après la page de confirmation
/// CIAM, ou l'échange de jeton peut bloquer. En horodatant chaque étape et en
/// l'affichant de façon **persistante** sur l'écran de connexion (voir
/// `sign_in_screen`), on voit EXACTEMENT la dernière étape atteinte avant un
/// éventuel timeout — sans logs distants ni reproduction à l'aveugle.
enum AuthDiagnosticStep {
  /// (1) La requête d'autorisation a été ouverte (navigateur système lancé).
  authorizeOpened,

  /// (2) Le code d'autorisation est revenu (le callback natif a été capté).
  callbackReturned,

  /// (3) L'échange du code contre des jetons a démarré (appel au token endpoint).
  tokenExchangeStarted,

  /// (4) Les jetons ont été reçus du serveur d'autorisation.
  tokenReceived,

  /// (5) La session a été écrite dans le stockage sécurisé.
  sessionWritten,

  /// Échec à l'étape courante (le [AuthDiagnosticEntry.detail] précise la cause).
  failed,
}

extension AuthDiagnosticStepX on AuthDiagnosticStep {
  /// Libellé FR court, aligné sur les étapes attendues côté diagnostic.
  String get label => switch (this) {
        AuthDiagnosticStep.authorizeOpened => 'authorize ouvert',
        AuthDiagnosticStep.callbackReturned => 'code reçu / callback revenu',
        AuthDiagnosticStep.tokenExchangeStarted => 'échange jeton en cours',
        AuthDiagnosticStep.tokenReceived => 'jeton reçu',
        AuthDiagnosticStep.sessionWritten => 'session écrite',
        AuthDiagnosticStep.failed => 'échec',
      };
}

/// Une entrée **horodatée** de la trace de diagnostic d'auth sociale.
@immutable
class AuthDiagnosticEntry {
  const AuthDiagnosticEntry({required this.at, required this.step, this.detail});

  /// Horodatage de capture de l'étape (heure murale locale).
  final DateTime at;

  /// Étape atteinte.
  final AuthDiagnosticStep step;

  /// Détail technique optionnel **non sensible** (ex. longueur d'un jeton, code
  /// d'erreur brut) — jamais le jeton lui-même ni de donnée personnelle.
  final String? detail;
}

/// Puits d'étapes de diagnostic, injecté dans la passerelle OIDC.
///
/// Interface minimale (sans dépendance Riverpod) afin que [AppAuthGateway]
/// puisse tracer chaque étape sans connaître le conteneur. L'implémentation
/// réelle est le notifier observable ci-dessous ; [NoopAuthDiagnostics] sert de
/// défaut inerte (tests, ou passerelle instanciée hors conteneur).
abstract interface class AuthDiagnostics {
  /// Ajoute une étape horodatée à la trace courante.
  void mark(AuthDiagnosticStep step, {String? detail});
}

/// Implémentation inerte (aucun effet) : défaut quand aucune trace n'est câblée.
class NoopAuthDiagnostics implements AuthDiagnostics {
  const NoopAuthDiagnostics();

  @override
  void mark(AuthDiagnosticStep step, {String? detail}) {}
}

/// Trace **observable** du dernier flux de connexion sociale.
///
/// `Notifier` synchrone (comme le contrôleur d'auth) exposant la liste ordonnée
/// des étapes atteintes ; l'écran de connexion l'observe pour afficher un
/// journal **persistant** et **sélectionnable**. Le fait de porter la trace dans
/// un provider (et non dans l'état local d'un widget) est essentiel : l'écran de
/// connexion est démonté puis remonté par le routeur pendant le flux
/// (AuthLoading → /splash, puis Unauthenticated → /auth), donc un état local
/// serait perdu ; la trace, elle, survit et reste affichable au retour.
class AuthDiagnosticsNotifier extends Notifier<List<AuthDiagnosticEntry>>
    implements AuthDiagnostics {
  @override
  List<AuthDiagnosticEntry> build() => const <AuthDiagnosticEntry>[];

  /// Vide la trace au démarrage d'une nouvelle tentative sociale.
  void reset() => state = const <AuthDiagnosticEntry>[];

  @override
  void mark(AuthDiagnosticStep step, {String? detail}) {
    state = <AuthDiagnosticEntry>[
      ...state,
      AuthDiagnosticEntry(at: DateTime.now(), step: step, detail: detail),
    ];
  }
}

/// Trace de diagnostic d'auth sociale, observée par l'écran de connexion et
/// alimentée par la passerelle OIDC + le contrôleur.
final authDiagnosticsProvider =
    NotifierProvider<AuthDiagnosticsNotifier, List<AuthDiagnosticEntry>>(
  AuthDiagnosticsNotifier.new,
);
