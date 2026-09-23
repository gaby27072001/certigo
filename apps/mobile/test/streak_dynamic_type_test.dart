import 'package:certigo/app/providers.dart';
import 'package:certigo/app/router.dart';
import 'package:certigo/features/streak/application/streak_repair_controller.dart';
import 'package:certigo/features/streak/presentation/streak_copy.dart';
import 'package:certigo/features/streak/presentation/streak_repair_banner.dart';
import 'package:certigo/features/streak/presentation/streak_screen.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/fake_streak_repository.dart';
import 'support/fake_user_repository.dart';
import 'support/prism_fonts.dart';

/// Dynamic Type reflow for « Ma série », measured with the real Prism fonts on
/// the iPhone 14/15/16 template — the method of `dynamic_type_reflow_guard_test`.
///
/// P0 rule: at the largest sizes no action is hidden and no text that carries
/// information is truncated. Three measures, at each scale: no layout overflow,
/// no truncated paragraph among the ones that carry the offer, and the repair
/// action reachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPrismFonts);

  const Size kPhone = Size(390, 844);
  const DefaultMaterialLocalizations l10n = DefaultMaterialLocalizations();

  void sizePhone(WidgetTester tester) {
    tester.view.physicalSize = kPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget scaled(double scale, Widget child) => Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      );

  Future<FakeStreakRepository> pumpScreen(
    WidgetTester tester,
    double scale,
    StreakStatus status,
  ) async {
    sizePhone(tester);
    final FakeStreakRepository repo = FakeStreakRepository(
      statuses: <Result<StreakStatus>>[Success<StreakStatus>(status)],
    )..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
    final GoRouter router = GoRouter(
      initialLocation: Routes.streak,
      routes: <RouteBase>[
        GoRoute(
          path: Routes.streak,
          builder: (BuildContext context, GoRouterState state) => const StreakScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          streakRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith((Ref ref) async => testUserProfile()),
          clientRepairIdGeneratorProvider.overrideWithValue(() => 'key-1'),
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => scaled(scale, child!),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return repo;
  }

  RenderParagraph? paragraphOf(WidgetTester tester, String text) {
    for (final RenderObject node in tester.allRenderObjects) {
      if (node is RenderParagraph && node.text.toPlainText() == text) return node;
    }
    return null;
  }

  void expectNoOverflow(WidgetTester tester, String where) {
    final Object? error = tester.takeException();
    expect(error, isNull, reason: '$where : la mise en page déborde à grand texte — $error');
  }

  /// Scrolls [text] into view first: at large sizes the offer is taller than
  /// the screen, and a lazy list only lays out what is near the viewport.
  Future<void> expectWhole(WidgetTester tester, String text, String where) async {
    await tester.scrollUntilVisible(
      find.text(text),
      120,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pump();
    final RenderParagraph? p = paragraphOf(tester, text);
    expect(p, isNotNull, reason: '$where : « $text » est absent du rendu.');
    expect(
      p!.didExceedMaxLines,
      isFalse,
      reason: '$where : « $text » (${text.length} c) est TRONQUÉ — peint sur '
          '${p.size.width.toStringAsFixed(1)}×${p.size.height.toStringAsFixed(1)} px.',
    );
  }

  for (final double scale in <double>[1.0, 1.5, 2.0, 3.0]) {
    testWidgets('offre @$scale× : rien ne déborde, rien n\'est amputé, l\'action est atteignable',
        (WidgetTester tester) async {
      final StreakStatus status = repairableStatus(gems: 30);
      await pumpScreen(tester, scale, status);
      final String where = 'offre @$scale×';

      expectNoOverflow(tester, where);
      for (final String text in <String>[
        StreakLabels.pausedTitle(12),
        StreakLabels.lastActive(formatStreakDay(l10n, status.lastActiveDate!)),
        StreakLabels.offerBody(12),
        StreakLabels.beforeGoal,
        StreakLabels.price(50),
        StreakLabels.balance(30),
        StreakLabels.deadline(
          formatRepairDeadline(
            l10n,
            status.repairExpiresAt!.toLocal(),
            alwaysUse24HourFormat: false,
          ),
        ),
        StreakLabels.missing(20),
        StreakLabels.missingHint,
        StreakLabels.repair,
      ]) {
        await expectWhole(tester, text, where);
      }
      expectNoOverflow(tester, where);
    });
  }

  for (final double scale in <double>[1.0, 2.0, 3.0]) {
    testWidgets('issue @$scale× : la réparation accordée se lit en entier', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, scale, repairableStatus());
      final String where = 'issue @$scale×';

      await tester.scrollUntilVisible(
        find.text(StreakLabels.repair),
        120,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      // Partly visible is not tappable: bring the whole button into view first.
      await tester.ensureVisible(find.text(StreakLabels.repair));
      await tester.pump();
      await tester.tap(find.text(StreakLabels.repair));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expectNoOverflow(tester, where);
      for (final String text in <String>[
        StreakLabels.grantedTitle,
        StreakLabels.grantedBody(12),
        StreakLabels.newBalance(70),
        StreakLabels.continueLearning,
      ]) {
        await expectWhole(tester, text, where);
      }
    });
  }

  for (final double scale in <double>[1.0, 2.0, 3.0]) {
    testWidgets('sans offre @$scale× : la raison et la suite restent lisibles', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, scale, blockedStatus('intact', freezeTokens: 2));
      final String where = 'intacte @$scale×';

      expectNoOverflow(tester, where);
      await expectWhole(tester, StreakLabels.intactTitle(12), where);
      await expectWhole(
        tester,
        '${StreakLabels.intactBody}\n${StreakLabels.freezeReserve(2)}',
        where,
      );
      await expectWhole(tester, StreakLabels.continueLearning, where);
    });
  }

  for (final double scale in <double>[1.0, 2.0, 3.0]) {
    testWidgets('invite d\'accueil @$scale× : titre et fenêtre refluent', (
      WidgetTester tester,
    ) async {
      sizePhone(tester);
      final StreakStatus status = repairableStatus();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            streakRepositoryProvider.overrideWithValue(
              FakeStreakRepository(statuses: <Result<StreakStatus>>[Success<StreakStatus>(status)]),
            ),
          ],
          child: MaterialApp(
            theme: PrismTheme.light(),
            home: scaled(
              scale,
              Scaffold(
                body: ListView(
                  padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
                  children: const <Widget>[StreakRepairBanner()],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final String where = 'invite @$scale×';

      expectNoOverflow(tester, where);
      await expectWhole(tester, StreakLabels.bannerTitle(12), where);
      await expectWhole(
        tester,
        StreakLabels.bannerBody(
          50,
          formatRepairDeadline(l10n, status.repairExpiresAt!.toLocal(),
              alwaysUse24HourFormat: false),
        ),
        where,
      );
    });
  }
}
