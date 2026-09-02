import 'dart:io';

import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/deep_links/application/deep_link_contract.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde de **non-régression** de la configuration deep-link `certigo://auth/`.
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

  test('Android déclare uniquement le host canonique possédé', () {
    final String gradle = resolve('android/app/build.gradle').readAsStringSync();
    final String manifest = resolve('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(gradle, contains('"certigo-app.com"'));
    expect(gradle, contains('appLinksHost != "certigo-app.com"'));
    expect(gradle, contains('appLinksHost: appLinksHost'));
    expect(gradle, contains('appLinksPathPrefix: appLinksPathPrefix'));
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(
      manifest,
      isNot(contains('android:scheme="certigo"')),
      reason: 'MainActivity ne doit pas concurrencer RedirectUriReceiverActivity pour OAuth.',
    );
    expect(manifest, contains(r'android:host="${appLinksHost}"'));
    for (final String path in <String>[
      '/learn/',
      '/assignments/',
      '/achievements/',
      '/account-deletion',
    ]) {
      expect(manifest, contains(path), reason: 'Route App Link absente: $path');
    }
    expect(manifest, contains(r'android:pathPrefix="${appLinksPathPrefix}/learn/"'));
  });

  test('iOS prépare le domaine canonique sans activer l\'entitlement', () {
    final String entitlements = resolve('ios/Runner/Runner.entitlements').readAsStringSync();
    final String releaseConfig = resolve('ios/Flutter/Release.xcconfig').readAsStringSync();
    final String project = resolve('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(entitlements, contains(r'applinks:$(CERTIGO_APP_LINKS_HOST)'));
    expect(releaseConfig, contains('CERTIGO_APP_LINKS_HOST=certigo-app.com'));
    expect(
      project,
      isNot(contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')),
      reason: 'L\'entitlement doit rester opt-in tant que les profils Apple ne le supportent pas.',
    );
  });

  test('le runtime utilise le host canonique mais reste désactivé par défaut', () {
    expect(certigoConfiguredLinkHost, certigoCanonicalLinkHost);
    expect(certigoCanonicalLinkHost, 'certigo-app.com');
    expect(certigoHttpsLinksEnabled, isFalse);
  });

  test('ENTRA_REDIRECT_URI utilise le schéma natif', () {
    final Uri redirect = Uri.parse(AppEnv.entraRedirectUri);
    expect(redirect.scheme, AppEnv.redirectScheme);
    expect(redirect.toString(), startsWith('certigo://auth'));
  });

  test('la validation de config n\'émet aucune erreur de redirection par défaut', () {
    // Config par défaut (dev) : le schéma de redirection est cohérent.
    final AppConfigReport report = AppEnv.validate();
    expect(report.issues.any((AppConfigIssue i) => i.key == 'ENTRA_REDIRECT_URI'), isFalse);
  });

  test('le fournisseur e-mail ne dépend pas du deep-link natif', () {
    // Garde documentaire : l'e-mail/mot de passe reste disponible même si le
    // deep-link social casse (chemins d'auth indépendants).
    expect(AuthProvider.email.id, 'email');
  });
}
