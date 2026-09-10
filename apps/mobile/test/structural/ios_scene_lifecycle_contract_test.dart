import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde de **non-régression** du cycle de vie `UIScene` côté iOS.
///
/// Apple (WWDC 2026, session 278) impose le cycle de vie `UIScene` dès que
/// l'application est compilée avec le SDK iOS 27 : sans `UISceneDelegate`, elle
/// **ne démarre plus**. La compilation, elle, réussit — c'est un échec au
/// lancement. Aucune de nos portes CI ne lance l'application iOS, et la version
/// de Xcode vient de la machine de build, pas d'un commit : la régression peut
/// donc arriver sans que personne ne touche au dépôt.
///
/// Ce fichier est la seule garde exécutable sous Windows. Il ne prouve pas que
/// l'application démarre — seul un simulateur le peut — mais il prouve que le
/// câblage attendu par Apple et par l'échafaudage Flutter 3.44.4 est présent, et
/// il rougit si quelqu'un le retire.
///
/// La forme asserée vient de l'échafaudage officiel Flutter 3.44.4
/// (`packages/flutter_tools/templates/app/ios.tmpl/Runner/`), pas d'une
/// invention locale.
void main() {
  // `flutter test` s'exécute depuis apps/mobile ; on remonte si besoin pour
  // rester robuste au répertoire courant.
  File resolve(String relative) {
    for (final String base in <String>['.', 'apps/mobile']) {
      final File f = File('$base/$relative');
      if (f.existsSync()) return f;
    }
    return File(relative);
  }

  String read(String relative) {
    final File file = resolve(relative);
    expect(file.existsSync(), isTrue, reason: 'Fichier introuvable (${file.path})');
    return file.readAsStringSync();
  }

  // Les assertions de *code* doivent porter sur du code : sans cela, une simple
  // mention du motif interdit dans un commentaire suffirait à faire rougir la
  // garde, et la garde finirait par être affaiblie pour la faire taire.
  String codeOnly(String source) {
    return source.split('\n').where((String line) => !line.trimLeft().startsWith('//')).join('\n');
  }

  group('cycle de vie UIScene iOS', () {
    test('SceneDelegate.swift existe et dérive de FlutterSceneDelegate', () {
      final String source = read('ios/Runner/SceneDelegate.swift');
      expect(
        source,
        contains('class SceneDelegate: FlutterSceneDelegate'),
        reason: 'Le délégué de scène doit dériver de FlutterSceneDelegate, comme '
            "l'échafaudage Flutter 3.44.4.",
      );
    });

    test('Info.plist déclare le manifeste de scène attendu par Apple', () {
      final String plist = read('ios/Runner/Info.plist');
      expect(
        plist,
        contains('UIApplicationSceneManifest'),
        reason: "Sans UIApplicationSceneManifest, l'app ne démarre pas sous SDK iOS 27.",
      );
      expect(
        plist,
        contains(r'<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>'),
        reason: 'UISceneDelegateClassName doit pointer sur notre SceneDelegate.',
      );
      expect(
        plist,
        contains('UISceneStoryboardFile'),
        reason: 'La scène doit charger Main.storyboard, sinon aucune vue Flutter '
            "n'est instanciée.",
      );
    });

    test('SceneDelegate.swift est réellement compilé par la cible Runner', () {
      final String pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        pbxproj,
        contains('SceneDelegate.swift in Sources'),
        reason: 'Un fichier présent sur disque mais absent de la phase Sources '
            "n'est jamais compilé : Info.plist référencerait une classe inexistante.",
      );
    });
  });

  group('canal de santé du rapport de crash', () {
    test('AppDelegate enregistre via le pont de moteur implicite', () {
      final String appDelegate = codeOnly(read('ios/Runner/AppDelegate.swift'));
      expect(
        appDelegate,
        contains('FlutterImplicitEngineDelegate'),
        reason: 'Sous cycle de vie de scène, la fenêtre appartient au '
            'SceneDelegate : seul le pont de moteur implicite fournit un '
            'messager valide.',
      );
      expect(
        appDelegate,
        contains('didInitializeImplicitFlutterEngine'),
        reason: "L'enregistrement des plugins doit avoir lieu dans le rappel du "
            'moteur implicite.',
      );
      expect(
        appDelegate,
        isNot(contains('window?.rootViewController')),
        reason: 'window est nil sous cycle de vie de scène ; y lire le contrôleur '
            'racine ferait sortir la fonction sans enregistrer le canal, et '
            "l'application démarrerait avec le rapport de crash distant éteint.",
      );
    });

    test('le nom du canal est identique côté Swift et côté Dart', () {
      const String channel = 'com.certigo.mobileapp/crash-reporting-health';
      expect(read('ios/Runner/AppDelegate.swift'), contains(channel));
      expect(read('lib/bootstrap/sentry_crash_reporting.dart'), contains(channel));
    });
  });
}
