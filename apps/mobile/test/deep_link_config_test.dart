import 'dart:io';

import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde de **non-régression** de la configuration deep-link `certigo://auth`.
///
/// Le callback OIDC (Microsoft/Google/Apple via Entra) ne revient dans l'app que
/// si le schéma `certigo` est déclaré nativement des DEUX côtés. Ce test lit les
/// fichiers natifs et échoue si la déclaration disparaît — sans appareil ni
/// tenant. Exécuté depuis la racine du package `apps/mobile`.
void main() {
  // `flutter test` s'exécute depuis apps/mobile ; on résout les fichiers natifs
  // relativement, en remontant si besoin pour être robuste au répertoire courant.
  File resolve(String relative) {
    for (final String base in <String>['.', 'apps/mobile']) {
      final File f = File('$base/$relative');
      if (f.existsSync()) return f;
    }
    return File(relative);
  }

  test('iOS Info.plist déclare le schéma d\'URL « certigo »', () {
    final File plist = resolve('ios/Runner/Info.plist');
    expect(plist.existsSync(), isTrue, reason: 'Info.plist introuvable (${plist.path})');
    final String content = plist.readAsStringSync();
    expect(content, contains('CFBundleURLSchemes'));
    expect(
      content,
      contains('<string>${AppEnv.redirectScheme}</string>'),
      reason: 'Le schéma « ${AppEnv.redirectScheme} » doit figurer dans CFBundleURLSchemes.',
    );
  });

  test('Android build.gradle déclare appAuthRedirectScheme = « certigo »', () {
    final File gradle = resolve('android/app/build.gradle');
    expect(gradle.existsSync(), isTrue, reason: 'build.gradle introuvable (${gradle.path})');
    final String content = gradle.readAsStringSync();
    expect(
      content,
      contains('appAuthRedirectScheme: "${AppEnv.redirectScheme}"'),
      reason: 'manifestPlaceholders doit fixer appAuthRedirectScheme = ${AppEnv.redirectScheme}.',
    );
  });

  test('ENTRA_REDIRECT_URI utilise le schéma natif', () {
    final Uri redirect = Uri.parse(AppEnv.entraRedirectUri);
    expect(redirect.scheme, AppEnv.redirectScheme);
  });

  test('la validation de config n\'émet aucune erreur de redirection par défaut', () {
    // Config par défaut (dev) : le schéma de redirection est cohérent.
    final AppConfigReport report = AppEnv.validate();
    expect(
      report.issues.any((AppConfigIssue i) => i.key == 'ENTRA_REDIRECT_URI'),
      isFalse,
    );
  });

  test('le fournisseur e-mail ne dépend pas du deep-link natif', () {
    // Garde documentaire : l'e-mail/mot de passe reste disponible même si le
    // deep-link social casse (chemins d'auth indépendants).
    expect(AuthProvider.email.id, 'email');
  });
}
