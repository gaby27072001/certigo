import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/share/application/share_intent.dart';
import 'package:certigo/features/share/presentation/daily_share_screen.dart';
import 'package:prism_ui/prism_ui.dart';

class _FakeShareIntent implements ShareIntent {
  String? lastText;
  String? lastSubject;
  int calls = 0;

  @override
  Future<void> shareText(String text, {String? subject}) async {
    calls++;
    lastText = text;
    lastSubject = subject;
  }
}

void main() {
  final ShareCard fakeCard = ShareCard(
    shareId: 'share-2025-01-06',
    displayName: 'Alex Martin',
    handle: 'alex#4242',
    streakDays: 12,
    level: 7,
    dailyXp: 42,
    dailyGoalXp: 50,
    goalMet: false,
    readinessScore: 68,
    trackCode: 'AZ-900',
    mascot: 'Nimbus',
    headline: '12 jours de serie',
    caption:
        '68% de preparation sur Microlingo ! Rejoins-moi avec le code ABCD12 🚀',
    referralCode: 'ABCD12',
    generatedAt: DateTime.utc(2025, 1, 6, 12),
  );

  Future<void> pumpDailyShare(
    WidgetTester tester,
    _FakeShareIntent shareIntent,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/share-daily',
      routes: <RouteBase>[
        GoRoute(
          path: '/share-daily',
          builder: (BuildContext context, GoRouterState state) =>
              const DailyShareScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dailyShareCardProvider.overrideWith((Ref ref) async => fakeCard),
          shareIntentProvider.overrideWithValue(shareIntent),
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('renders the headline, referral code and share CTA', (
    WidgetTester tester,
  ) async {
    final _FakeShareIntent shareIntent = _FakeShareIntent();
    await pumpDailyShare(tester, shareIntent);

    expect(find.text('Partage du jour'), findsOneWidget);
    expect(find.text('12 jours de serie'), findsOneWidget);
    expect(find.text('ABCD12'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Partager'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Partager'), findsOneWidget);
  });

  testWidgets(
    'shares the generated message and confirms copied referral code',
    (WidgetTester tester) async {
      final _FakeShareIntent shareIntent = _FakeShareIntent();
      await pumpDailyShare(tester, shareIntent);

      await tester.scrollUntilVisible(
        find.text('Partager'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Partager'));
      await tester.pump();

      expect(shareIntent.calls, 1);
      expect(shareIntent.lastSubject, 'Certigo • AZ-900');
      expect(shareIntent.lastText, contains(fakeCard.headline));
      expect(shareIntent.lastText, contains('ref=ABCD12'));
      expect(shareIntent.lastText, contains('share=share-2025-01-06'));

      await tester.scrollUntilVisible(
        find.text('Copier le code').first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Copier le code').first);
      await tester.pump();

      expect(find.text('Code copie.'), findsOneWidget);
    },
  );
}
