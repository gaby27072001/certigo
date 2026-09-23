import 'dart:async';

import 'package:certigo/app/providers.dart';
import 'package:certigo/app/router.dart';
import 'package:certigo/features/streak/application/streak_repair_controller.dart';
import 'package:certigo/features/streak/presentation/streak_copy.dart';
import 'package:certigo/features/streak/presentation/streak_screen.dart';
import 'package:certigo/shared/errors/error_copy.dart';
import 'package:certigo/shared/widgets/async_module.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/error_message.dart';
import 'support/fake_streak_repository.dart';
import 'support/fake_user_repository.dart';

void main() {
  const DefaultMaterialLocalizations l10n = DefaultMaterialLocalizations();

  /// Hosts « Ma série » on its route, with the two destinations it can lead to.
  Future<ProviderContainer> pumpStreak(
    WidgetTester tester,
    FakeStreakRepository repo, {
    ThemeData? theme,
    ProviderContainer? container,
    bool disableAnimations = false,
  }) async {
    // Tall enough that the whole offer builds under the square test glyphs.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    int minted = 0;
    final ProviderContainer scope = container ??
        ProviderContainer(
          overrides: <Override>[
            streakRepositoryProvider.overrideWithValue(repo),
            meProvider.overrideWith((Ref ref) async => testUserProfile()),
            clientRepairIdGeneratorProvider.overrideWithValue(() => 'key-${++minted}'),
          ],
        );
    addTearDown(scope.dispose);

    final GoRouter router = GoRouter(
      initialLocation: Routes.streak,
      routes: <RouteBase>[
        GoRoute(
          path: Routes.streak,
          builder: (BuildContext context, GoRouterState state) => const StreakScreen(),
        ),
        GoRoute(
          path: Routes.path,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('PARCOURS')),
        ),
        GoRoute(
          path: Routes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('ACCUEIL')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(
          theme: theme ?? PrismTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
        ),
      ),
    );
    // Never pumpAndSettle: skeletons loop while a read is held.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return scope;
  }

  Future<void> settleRuling(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Past the morph between the offer and its outcome.
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A loading PrismButton paints a spinner instead of its label, so it can only
  /// be found by type — the offer card holds a single button.
  PrismButton repairButton(
    WidgetTester tester, {
    String label = StreakLabels.repair,
    bool byType = false,
  }) =>
      tester.widget<PrismButton>(
        byType ? find.byType(PrismButton) : find.widgetWithText(PrismButton, label),
      );

  List<String> keysSent(FakeStreakRepository repo) =>
      repo.requests.map((StreakRepairRequest r) => r.clientRepairId).toList();

  group('l\'offre dit tout ce que le serveur a décidé', () {
    testWidgets('la série, le jour, le prix, le solde, la fenêtre, le piège et l\'action', (
      WidgetTester tester,
    ) async {
      final StreakStatus status = repairableStatus();
      await pumpStreak(tester, FakeStreakRepository());

      expect(find.text(StreakLabels.pausedTitle(12)), findsOneWidget);
      expect(
        find.text(StreakLabels.lastActive(formatStreakDay(l10n, DateTime.utc(2025, 1, 3)))),
        findsOneWidget,
      );
      expect(find.text(StreakLabels.price(50)), findsOneWidget);
      expect(find.text(StreakLabels.balance(120)), findsOneWidget);
      expect(
        find.text(
          StreakLabels.deadline(
            formatRepairDeadline(
              l10n,
              status.repairExpiresAt!.toLocal(),
              alwaysUse24HourFormat: false,
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(StreakLabels.beforeGoal), findsOneWidget);
      expect(repairButton(tester).onPressed, isNotNull);
    });

    testWidgets('un solde connu insuffisant désactive l\'action et dit combien il manque', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository(
        statuses: <Result<StreakStatus>>[Success<StreakStatus>(repairableStatus(gems: 30))],
      );
      await pumpStreak(tester, repo);

      expect(find.text(StreakLabels.missing(20)), findsOneWidget);
      expect(find.text(StreakLabels.missingHint), findsOneWidget);
      expect(repairButton(tester).onPressed, isNull);

      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);
      expect(repo.requests, isEmpty);
    });

    testWidgets('un gel qui couvre le jour manqué passe avant la réparation', (
      WidgetTester tester,
    ) async {
      await pumpStreak(
        tester,
        FakeStreakRepository(
          statuses: <Result<StreakStatus>>[
            Success<StreakStatus>(repairableStatus(freezeTokens: 1, coveredByFreeze: true)),
          ],
        ),
      );

      expect(find.text(StreakLabels.freezeTitle), findsOneWidget);
      expect(find.text(StreakLabels.freezeBody(12)), findsOneWidget);
      expect(find.text(StreakLabels.freezeRepairNote), findsOneWidget);
      // Not the trap it would be without a freeze: meeting the goal saves it here.
      expect(find.text(StreakLabels.beforeGoal), findsNothing);
      final PrismButton button = repairButton(tester, label: StreakLabels.repairAnyway);
      expect(button.variant, PrismButtonVariant.secondary);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('un serveur antérieur sans solde ni fenêtre laisse le serveur trancher', (
      WidgetTester tester,
    ) async {
      await pumpStreak(
        tester,
        FakeStreakRepository(
          statuses: <Result<StreakStatus>>[
            Success<StreakStatus>(repairableStatus(gems: null, withDeadline: false)),
          ],
        ),
      );

      expect(find.textContaining('Ton solde'), findsNothing, reason: 'never an invented balance');
      expect(find.text(StreakLabels.noDeadline), findsOneWidget);
      expect(repairButton(tester).onPressed, isNotNull);
    });

    testWidgets('un gel qui couvre le jour manqué ne dit jamais que l\'objectif relance la série', (
      WidgetTester tester,
    ) async {
      // Found in review: short of gems with a freeze covering the gap, the hint
      // said meeting the goal restarts the streak — the opposite of the server
      // rule, and a push away from the one free fix.
      await pumpStreak(
        tester,
        FakeStreakRepository(
          statuses: <Result<StreakStatus>>[
            Success<StreakStatus>(
              repairableStatus(gems: 30, freezeTokens: 1, coveredByFreeze: true),
            ),
          ],
        ),
      );

      expect(find.text(StreakLabels.missing(20)), findsOneWidget);
      expect(find.text(StreakLabels.missingFreezeHint), findsOneWidget);
      expect(find.text(StreakLabels.missingHint), findsNothing);
      expect(find.text(StreakLabels.freezeBody(12)), findsOneWidget);
    });

    testWidgets('une relecture ratée garde l\'offre à l\'écran, mais aucune gemme ne part dessus', (
      WidgetTester tester,
    ) async {
      // Found in review: after a failed re-read the old value stays beside the
      // error and `isLoading` is false again, so the repair had been re-enabled
      // on a snapshot that could be hours old.
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final ProviderContainer container = await pumpStreak(tester, repo);
      repo.serveStatus(const Err<StreakStatus>(NetworkFailure()));
      try {
        await container.refresh(streakStatusProvider.future);
      } catch (_) {
        // Surfaced by the AsyncValue, exactly as refreshQuietly does.
      }
      await settleRuling(tester);

      expect(find.text(StreakLabels.pausedTitle(12)), findsOneWidget);
      expect(find.text(StreakLabels.unverifiedTitle), findsOneWidget);
      expect(repairButton(tester).onPressed, isNull);
      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);
      expect(repo.requests, isEmpty);

      // The way out is a button, reachable with VoiceOver — not only a pull.
      repo.serveStatus(Success<StreakStatus>(repairableStatus()));
      await tester.tap(find.text(StreakLabels.recheck));
      await settleRuling(tester);

      expect(find.text(StreakLabels.unverifiedTitle), findsNothing);
      expect(repairButton(tester).onPressed, isNotNull);
      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);
      expect(repo.requests, hasLength(1));
      expect(find.text(StreakLabels.grantedTitle), findsOneWidget);
    });
  });

  group('réparer', () {
    testWidgets('une seule demande, puis le résultat du serveur, puis la suite', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      await pumpStreak(tester, repo);
      expect(repo.statusCalls, 1);

      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);

      expect(keysSent(repo), <String>['key-1']);
      expect(find.text(StreakLabels.grantedTitle), findsOneWidget);
      expect(find.text(StreakLabels.grantedBody(12)), findsOneWidget);
      expect(find.text(StreakLabels.newBalance(70)), findsOneWidget);
      expect(repo.statusCalls, 2, reason: 'the ruling re-reads the authoritative streak');

      await tester.tap(find.text(StreakLabels.continueLearning));
      await settleRuling(tester);
      expect(find.text('PARCOURS'), findsOneWidget);
    });

    testWidgets('pendant la demande, l\'action est occupée et un second appui n\'envoie rien', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..hold = Completer<void>()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      await pumpStreak(tester, repo);

      await tester.tap(find.text(StreakLabels.repair));
      await tester.pump();
      expect(repairButton(tester, byType: true).loading, isTrue);

      await tester.tap(find.byType(PrismButton));
      await tester.pump();
      expect(repo.requests, hasLength(1));

      repo.hold!.complete();
      await settleRuling(tester);
      expect(find.text(StreakLabels.grantedTitle), findsOneWidget);
    });

    testWidgets('un refus dit sa cause, que rien n\'a été débité, et relit la série', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(Success<StreakRepairResult>(refusedRepair('insufficientGems')));
      await pumpStreak(tester, repo);
      // Meanwhile the balance moved: the server's re-read is what the screen shows.
      repo.serveStatus(Success<StreakStatus>(repairableStatus(gems: 30)));

      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);

      expect(
        find.text(refusalMessage(refusedRepair('insufficientGems'))),
        findsOneWidget,
      );
      expect(find.textContaining(StreakLabels.notCharged), findsOneWidget);
      expect(repo.statusCalls, 2);
      expect(find.text(StreakLabels.missing(20)), findsOneWidget);
      expect(repairButton(tester).onPressed, isNull);
    });

    testWidgets('un refus « déjà intacte » laisse voir la série intacte, sans débit', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(Success<StreakRepairResult>(refusedRepair('noLongerRepairable')));
      await pumpStreak(tester, repo);
      repo.serveStatus(Success<StreakStatus>(blockedStatus('intact')));

      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);

      expect(find.text(StreakLabels.intactTitle(12)), findsOneWidget);
      expect(
        find.text('${StreakLabels.refusedIntact} ${StreakLabels.notCharged}'),
        findsOneWidget,
      );
    });

    testWidgets('une réponse perdue dit la cause, promet un seul débit, et rejoue la même clé', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(const Err<StreakRepairResult>(NetworkFailure.responseTimeout()))
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      await pumpStreak(tester, repo);

      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);

      expect(find.text(StreakLabels.failedTitle), findsOneWidget);
      expect(find.textContaining(StreakLabels.neverTwice), findsOneWidget);
      expectNoTechnicalText(tester, context: 'réparation / réponse perdue');
      expect(repo.statusCalls, 1, reason: 'no ruling: nothing is known to have moved');
      expect(repairButton(tester).onPressed, isNotNull, reason: 'the retry must stay one tap away');

      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);

      expect(keysSent(repo), <String>['key-1', 'key-1']);
      expect(find.text(StreakLabels.grantedTitle), findsOneWidget);
    });

    testWidgets('une série déjà en cache est relue avant qu\'une gemme puisse partir', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository();
      int minted = 0;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          streakRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith((Ref ref) async => testUserProfile()),
          clientRepairIdGeneratorProvider.overrideWithValue(() => 'key-${++minted}'),
        ],
      );
      // Home read it earlier and keeps it alive.
      container.listen(streakStatusProvider, (_, __) {});
      await container.read(streakStatusProvider.future);
      repo.holdStatus = Completer<void>();

      await pumpStreak(tester, repo, container: container);

      expect(repo.statusCalls, 2, reason: 'opening the screen re-reads a cached snapshot');
      expect(find.text(StreakLabels.checking), findsOneWidget);
      expect(repairButton(tester).onPressed, isNull);

      repo.holdStatus!.complete();
      repo.holdStatus = null;
      await settleRuling(tester);
      expect(find.text(StreakLabels.checking), findsNothing);
      expect(repairButton(tester).onPressed, isNotNull);
    });
  });

  group('sans offre, l\'écran dit pourquoi et propose la suite', () {
    Future<void> expectLeadsToPath(WidgetTester tester, String action) async {
      final PrismStatusView view = tester.widget<PrismStatusView>(find.byType(PrismStatusView));
      expect(view.actionLabel, action);
      expect(view.actionIcon, isNot(Icons.refresh_rounded));
      await tester.tap(find.text(action));
      await settleRuling(tester);
      expect(find.text('PARCOURS'), findsOneWidget);
    }

    testWidgets('intacte, avec la réserve de gels', (WidgetTester tester) async {
      await pumpStreak(
        tester,
        FakeStreakRepository(
          statuses: <Result<StreakStatus>>[
            Success<StreakStatus>(blockedStatus('intact', freezeTokens: 1)),
          ],
        ),
      );

      expect(find.text(StreakLabels.intactTitle(12)), findsOneWidget);
      expect(find.textContaining(StreakLabels.freezeReserve(1)), findsOneWidget);
      expect(find.byType(PrismButton), findsOneWidget, reason: 'no repair where none is offered');
      await expectLeadsToPath(tester, StreakLabels.continueLearning);
    });

    testWidgets('expirée', (WidgetTester tester) async {
      await pumpStreak(
        tester,
        FakeStreakRepository(
          statuses: <Result<StreakStatus>>[Success<StreakStatus>(blockedStatus('expired'))],
        ),
      );

      expect(find.text(StreakLabels.expiredTitle(12)), findsOneWidget);
      expect(find.text(StreakLabels.expiredBody), findsOneWidget);
      await expectLeadsToPath(tester, StreakLabels.startLesson);
    });

    testWidgets('pas encore de série', (WidgetTester tester) async {
      await pumpStreak(
        tester,
        FakeStreakRepository(
          statuses: <Result<StreakStatus>>[
            Success<StreakStatus>(blockedStatus('noStreak', streakDays: 0)),
          ],
        ),
      );

      expect(find.text(StreakLabels.noneTitle), findsOneWidget);
      await expectLeadsToPath(tester, StreakLabels.startLesson);
    });

    testWidgets('une raison que cette version ne connaît pas', (WidgetTester tester) async {
      await pumpStreak(
        tester,
        FakeStreakRepository(
          statuses: <Result<StreakStatus>>[Success<StreakStatus>(blockedStatus('paused'))],
        ),
      );

      expect(find.text(StreakLabels.unavailableTitle), findsOneWidget);
      await expectLeadsToPath(tester, StreakLabels.continueLearning);
    });
  });

  group('chargement, échec et rafraîchissement', () {
    testWidgets('rien encore : la forme du contenu, sans action', (WidgetTester tester) async {
      final FakeStreakRepository repo = FakeStreakRepository()..holdStatus = Completer<void>();
      await pumpStreak(tester, repo);

      expect(find.byType(PrismSkeleton), findsWidgets);
      expect(find.byType(PrismButton), findsNothing);
      expect(find.text(StreakLabels.title), findsOneWidget, reason: 'the way back stays');

      repo.holdStatus!.complete();
      await settleRuling(tester);
    });

    for (final probe in realisticFailures) {
      testWidgets('échec froid / ${probe.name} : cause et action, jamais la technique', (
        WidgetTester tester,
      ) async {
        final FakeStreakRepository repo = FakeStreakRepository(
          statuses: <Result<StreakStatus>>[Err<StreakStatus>(probe.failure)],
        );
        await pumpStreak(tester, repo);

        final ErrorCopy copy = streakStatusErrorCopy(probe.failure);
        expectNoTechnicalText(tester, context: 'Ma série / ${probe.name}');
        expect(find.text(copy.title), findsOneWidget);
        expect(find.text(copy.message), findsOneWidget);
        expect(find.text(StreakLabels.title), findsOneWidget, reason: 'the way back stays');

        await tester.tap(find.text(copy.actionLabel));
        await settleRuling(tester);
        if (copy.retryResolves) {
          expect(repo.statusCalls, 2, reason: 'the retry really reloads the streak');
        } else {
          expect(find.text('ACCUEIL'), findsOneWidget, reason: 'a dead end leads Home');
        }
      });
    }

    testWidgets('un rafraîchissement qui échoue garde la série à l\'écran', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository();
      final ProviderContainer container = await pumpStreak(tester, repo);
      repo.serveStatus(const Err<StreakStatus>(ServerFailure('boom', statusCode: 503)));

      try {
        await container.refresh(streakStatusProvider.future);
      } catch (_) {
        // Surfaced by the AsyncValue, exactly as refreshQuietly does.
      }
      await settleRuling(tester);

      expect(find.text(StreakLabels.pausedTitle(12)), findsOneWidget);
      expect(find.text(AsyncModule.defaultStaleMessage), findsOneWidget);
      expectNoTechnicalText(tester, context: 'Ma série / rafraîchissement');
    });

    testWidgets('tirer vers le bas relit la série', (WidgetTester tester) async {
      final FakeStreakRepository repo = FakeStreakRepository();
      await pumpStreak(tester, repo);

      await tester.fling(find.byType(ListView).first, const Offset(0, 600), 1200);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(repo.statusCalls, greaterThan(1));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('accessibilité', () {
    testWidgets('chaque cible fait au moins 44 pt et porte un nom', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpStreak(tester, FakeStreakRepository());

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('VoiceOver nomme l\'action, annonce l\'attente, puis l\'issue', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final FakeStreakRepository repo = FakeStreakRepository()
        ..hold = Completer<void>()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      await pumpStreak(tester, repo);

      final Finder action = find.bySemanticsLabel(StreakLabels.repair);
      expect(action, findsOneWidget, reason: 'the action is one node, named by its label');
      expect(
        tester.getSemantics(action),
        containsSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );

      await tester.tap(find.text(StreakLabels.repair));
      await tester.pump();
      expect(
        find.bySemanticsLabel('${StreakLabels.repair}, chargement'),
        findsOneWidget,
        reason: 'the wait is announced, not silent',
      );

      repo.hold!.complete();
      await settleRuling(tester);
      final Finder liveOutcome = find.ancestor(
        of: find.text(StreakLabels.grantedTitle),
        matching: find.byWidgetPredicate(
          (Widget w) => w is Semantics && (w.properties.liveRegion ?? false),
        ),
      );
      expect(liveOutcome, findsWidgets, reason: 'the outcome is announced as it appears');
      handle.dispose();
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('Increase Contrast + Reduce Transparency ($brightness) : opaque et lisible', (
        WidgetTester tester,
      ) async {
        await pumpStreak(
          tester,
          FakeStreakRepository(),
          theme: PrismTheme.resolve(
            brightness: brightness,
            highContrast: true,
            reduceTransparency: true,
          ),
        );

        expect(find.text(StreakLabels.pausedTitle(12)), findsOneWidget);
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason: 'Reduce Transparency asks for no blur at all, header included',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('retour haptique et mouvement', () {
    late List<String> vibrations;

    setUp(() {
      vibrations = <String>[];
      PrismHaptics.enabled = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') vibrations.add('${call.arguments}');
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('dépenser des gemmes est un engagement : une vibration légère, une seule', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      await pumpStreak(tester, repo);
      expect(vibrations, isEmpty, reason: 'opening the screen does not vibrate');

      await tester.tap(find.text(StreakLabels.repair));
      await settleRuling(tester);

      expect(repo.requests, hasLength(1), reason: 'the tap reached the button');
      expect(vibrations, <String>['HapticFeedbackType.lightImpact']);
    });

    testWidgets('sous mouvement réduit, l\'issue remplace l\'offre sans transition', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      await pumpStreak(tester, repo, disableAnimations: true);

      await tester.tap(find.text(StreakLabels.repair));
      await tester.pump();
      await tester.pump();

      expect(find.text(StreakLabels.grantedTitle), findsOneWidget);
      expect(find.text(StreakLabels.offerTitle), findsNothing);
    });

    testWidgets('sinon, l\'offre se transforme en issue plutôt que d\'être remplacée', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = FakeStreakRepository()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      await pumpStreak(tester, repo);

      await tester.tap(find.text(StreakLabels.repair));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Mid-morph, both states are on screen: the control that proves the test
      // above measures the setting and not an absent transition.
      expect(find.text(StreakLabels.grantedTitle), findsOneWidget);
      expect(find.text(StreakLabels.offerTitle), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(StreakLabels.offerTitle), findsNothing);
    });
  });
}
