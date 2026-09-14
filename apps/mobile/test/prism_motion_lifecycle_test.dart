import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Garde de **mise au repos des boucles d'animation en arrière-plan**.
///
/// Trois composants Prism entretiennent une boucle infinie
/// (`AnimationController.repeat()`) : [OrbitField], [PathNode] et
/// [PrismSkeleton]. Hors écran, une boucle ne peut rien informer : elle ne fait
/// plus que consommer de la batterie. DESIGN.md §10, règle 6 — « le mouvement
/// informe ; il ne décore pas ».
///
/// **Pourquoi cette garde vit dans la suite de l'app et non dans `prism_ui`.**
/// Mesuré sur `.github/workflows/` : sur une pull request, la CI n'exécute
/// qu'un seul fichier de test de `prism_ui` — `test/rendering/
/// renderer_golden_test.dart` (`ci-mobile.yml:331`). Les autres suites Flutter
/// gatées sont `apps/mobile` (`ci-mobile.yml:231`) et les paquets Dart purs
/// `core`/`cortex`/`data` (`ci-mobile.yml:130`). Une garde posée dans
/// `packages/prism_ui/test/components/` ne pourrait donc jamais faire rougir la
/// CI — et « une garde qui ne peut pas échouer est une décoration »
/// (DESIGN.md §10). Elle est donc posée ici, où elle mord, et sans ajouter la
/// moindre minute de runner. Le dépôt a déjà ce précédent :
/// `test/structural/token_contract_test.dart` vérifie des invariants `prism_ui`
/// depuis la suite de l'app, pour la même raison.
///
/// L'instrument est [SchedulerBinding.transientCallbackCount] : un `Ticker` en
/// marche maintient exactement un callback de frame enregistré entre deux
/// frames. Zéro signifie « plus aucune horloge d'animation n'est armée ».
///
/// L'instrument est **auto-vérifiant** : chaque cas contrôle d'abord qu'il voit
/// une boucle tourner avant d'exiger qu'elle s'arrête. Un instrument muet doit
/// échouer, pas rendre zéro (GOVERNANCE.md §7).
void main() {
  Future<void> pumpPrism(
    WidgetTester tester,
    Widget child, {
    bool disableAnimations = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: PrismTheme.light(),
        builder: (BuildContext context, Widget? appChild) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
            child: appChild!,
          );
        },
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  /// Envoie un changement de cycle de vie par le canal plateforme public, en
  /// suivant la suite d'états légale (`resumed → inactive → hidden → paused`).
  Future<void> setLifecycle(WidgetTester tester, List<AppLifecycleState> path) async {
    for (final AppLifecycleState state in path) {
      final ByteData? message = const StringCodec().encodeMessage(state.toString());
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        message,
        (ByteData? _) {},
      );
    }
    await tester.pump();
  }

  Future<void> sendToBackground(WidgetTester tester) => setLifecycle(tester, <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);

  Future<void> bringToForeground(WidgetTester tester) => setLifecycle(tester, <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

  /// Nombre d'horloges d'animation armées. Se lit entre deux frames.
  int armedTickers(WidgetTester tester) => tester.binding.transientCallbackCount;

  /// Laisse la boucle démarrer sans jamais `pumpAndSettle` (elle est infinie).
  Future<void> letTheLoopStart(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 100));

  // Les trois sites qui appellent `repeat()` dans prism_ui.
  final Map<String, Widget> loopingComponents = <String, Widget>{
    'OrbitField': const OrbitField(
      center: Text('C'),
      ringRadii: <double>[60],
      items: <OrbitItem>[OrbitItem(ring: 0, angle: 0, child: Text('A'))],
    ),
    'PathNode': const PathNode(
      status: PathNodeStatus.available,
      current: true,
      startLabel: 'COMMENCER',
    ),
    'PrismSkeleton': const PrismSkeleton(width: 120),
  };

  loopingComponents.forEach((String name, Widget component) {
    group('$name — mise au repos en arrière-plan', () {
      testWidgets('arrête sa boucle en arrière-plan et la reprend au retour', (
        WidgetTester tester,
      ) async {
        await pumpPrism(tester, component);
        await letTheLoopStart(tester);

        // Contrôle positif : sans lui, un zéro plus bas ne prouverait rien.
        expect(
          armedTickers(tester),
          greaterThan(0),
          reason: 'contrôle positif — au premier plan, la boucle doit tourner, '
              'sinon cette garde ne mesure rien',
        );

        await sendToBackground(tester);
        expect(
          armedTickers(tester),
          0,
          reason: 'hors écran, une boucle ne peut rien informer : elle ne fait '
              'que consommer de la batterie',
        );

        await bringToForeground(tester);
        await letTheLoopStart(tester);
        expect(
          armedTickers(tester),
          greaterThan(0),
          reason: 'au retour au premier plan, le mouvement doit revenir',
        );
      });

      testWidgets('mouvement réduit et arrière-plan coexistent', (WidgetTester tester) async {
        await pumpPrism(tester, component, disableAnimations: true);
        await letTheLoopStart(tester);

        // Acquis du dépôt : sous mouvement réduit, aucune boucle n'est armée.
        expect(
          armedTickers(tester),
          0,
          reason: 'acquis mesuré — le mouvement réduit met déjà ce composant au repos',
        );

        await sendToBackground(tester);
        expect(armedTickers(tester), 0);

        await bringToForeground(tester);
        await letTheLoopStart(tester);
        expect(
          armedTickers(tester),
          0,
          reason: 'revenir au premier plan ne doit pas réveiller une boucle que '
              'le mouvement réduit interdit — la mise au repos s’ajoute à cet '
              'acquis, elle ne le remplace pas',
        );
      });
    });
  });
}
