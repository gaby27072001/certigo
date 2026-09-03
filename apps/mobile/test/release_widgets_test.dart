import 'package:certigo/app/capabilities/release_profile_provider.dart';
import 'package:certigo/app/capabilities/release_widgets.dart';
import 'package:certigo/features/profile/presentation/widgets/app_info_section.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  Future<void> pumpAction(
    WidgetTester tester, {
    required ReleaseProfile profile,
    required Locale locale,
    required VoidCallback onPressed,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[releaseProfileProvider.overrideWithValue(profile)],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: PrismTheme.light(),
          home: Scaffold(
            body: Center(
              child: CapabilityAction(
                capability: AppCapability.socialFriends,
                semanticLabel: locale.languageCode == 'fr' ? 'Amis' : 'Friends',
                onPressed: onPressed,
                builder: (_, CapabilityAvailability availability) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(locale.languageCode == 'fr' ? 'Amis' : 'Friends'),
                    const SizedBox(width: 8),
                    CapabilityStatusBadge(availability: availability),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('upcoming is visible, disabled and inert in French', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpAction(
      tester,
      profile: ReleaseProfile.privateAlpha,
      locale: const Locale('fr'),
      onPressed: () => taps++,
    );

    expect(find.text('Bientôt'), findsOneWidget);
    expect(find.bySemanticsLabel('Amis, indisponible, bientôt'), findsOneWidget);
    expect(find.byType(PrismPressable), findsNothing);
    await tester.tap(find.text('Amis'));
    await tester.pump();
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('upcoming semantics are localized in English', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpAction(
      tester,
      profile: ReleaseProfile.privateAlpha,
      locale: const Locale('en'),
      onPressed: () {},
    );

    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.bySemanticsLabel('Friends, unavailable, coming soon'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('enabled future state preserves interaction', (WidgetTester tester) async {
    var taps = 0;
    await pumpAction(
      tester,
      profile: ReleaseProfile.full,
      locale: const Locale('fr'),
      onPressed: () => taps++,
    );

    expect(find.text('Bientôt'), findsNothing);
    expect(find.byType(PrismPressable), findsOneWidget);
    await tester.tap(find.text('Amis'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('off state hides the access point', (WidgetTester tester) async {
    await pumpAction(
      tester,
      profile: ReleaseProfile.failClosed,
      locale: const Locale('fr'),
      onPressed: () {},
    );

    expect(find.text('Amis'), findsNothing);
    expect(find.byType(PrismPressable), findsNothing);
  });

  testWidgets('private Alpha indicator is discreet and absent from full', (
    WidgetTester tester,
  ) async {
    Future<void> pump(ReleaseProfile profile) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[releaseProfileProvider.overrideWithValue(profile)],
          child: MaterialApp(
            locale: const Locale('fr'),
            supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: PrismTheme.light(),
            home: const Scaffold(body: AppInfoSection()),
          ),
        ),
      );
    }

    await pump(ReleaseProfile.privateAlpha);
    expect(find.byKey(const Key('private-alpha-indicator')), findsOneWidget);
    expect(find.text('Alpha privée'), findsOneWidget);
    expect(find.text('5 testeurs max.'), findsOneWidget);

    await pump(ReleaseProfile.full);
    expect(find.byKey(const Key('private-alpha-indicator')), findsNothing);
  });

  testWidgets('upcoming button supports narrow screens and large text', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          releaseProfileProvider.overrideWithValue(ReleaseProfile.privateAlpha),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: PrismTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: CapabilitySecondaryButton(
                  capability: AppCapability.socialSharing,
                  label: 'Partager le score du jour',
                  icon: Icons.share_rounded,
                  onPressed: _unexpectedTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel('Partager le score du jour, indisponible, bientôt'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

void _unexpectedTap() {
  throw StateError('Upcoming actions must not invoke their callback.');
}
