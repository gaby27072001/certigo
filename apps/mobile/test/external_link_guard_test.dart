import 'dart:io';

import 'package:certigo/app/external_link_guard.dart';
import 'package:certigo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Garde des liens entrants : sur iOS, tout `certigo://…` ouvert par une page
/// web ou une autre app est poussé vers le routeur par Flutter (3.27 et plus).
/// Seules les destinations de [externalLinkDestination] doivent l'atteindre.
void main() {
  group('externalLinkDestination', () {
    test('le lien de partage ouvre l\'accueil, sans lire ses paramètres', () {
      expect(externalLinkDestination(Uri.parse('certigo://home')), Routes.home);
      expect(externalLinkDestination(Uri.parse('certigo://home/')), Routes.home);
      expect(
        externalLinkDestination(Uri.parse('certigo://home?ref=ABC123&share=daily')),
        Routes.home,
      );
      expect(externalLinkDestination(Uri.parse('/home')), Routes.home);
    });

    test('toute autre destination est ignorée', () {
      for (final String link in <String>[
        'certigo://auth/?code=abc&state=def',
        'certigo://x/account/delete',
        'certigo://account/delete',
        'certigo://home/../account/delete',
        'certigo://home/quiz/az-900/l1',
        'certigo://enterprise/org-1',
        'certigo://x/quiz/az-900/..%2F..%2Fme',
        '/account/delete',
        '/enterprise/org-1',
        '/',
        '',
        'https://evil.example/home',
        'https://certigo.example/home',
        'other://home',
      ]) {
        expect(externalLinkDestination(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  group('ExternalLinkScope', () {
    GoRouter buildRouter() => GoRouter(
          initialLocation: Routes.splash,
          overridePlatformDefaultLocation: true,
          routes: <RouteBase>[
            for (final String path in <String>[
              Routes.splash,
              Routes.home,
              Routes.accountDeletion,
              '${Routes.manager}/:organizationId',
            ])
              GoRoute(path: path, builder: (_, GoRouterState state) => Text(state.uri.path)),
          ],
        );

    Future<void> openFromOutside(WidgetTester tester, String location) async {
      final ByteData message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', <String, Object?>{'location': location, 'state': null}),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        message,
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    String location(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

    testWidgets('sans la garde, un lien externe ouvre n\'importe quelle route', (
      WidgetTester tester,
    ) async {
      final GoRouter router = buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await openFromOutside(tester, 'certigo://x/account/delete');

      expect(location(router), Routes.accountDeletion, reason: 'raison d\'être de la garde');
      expect(find.text(Routes.accountDeletion), findsOneWidget);
    });

    testWidgets('avec la garde, seul le lien de partage navigue', (WidgetTester tester) async {
      final GoRouter router = buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ExternalLinkScope(router: router, child: MaterialApp.router(routerConfig: router)),
      );
      expect(location(router), Routes.splash);

      for (final String link in <String>[
        'certigo://x/account/delete',
        'certigo://account/delete',
        '/account/delete',
        'certigo://x/enterprise/org-1',
        'certigo://auth/?code=abc&state=def',
      ]) {
        await openFromOutside(tester, link);
        expect(location(router), Routes.splash, reason: link);
        expect(find.text(Routes.splash), findsOneWidget, reason: link);
      }

      await openFromOutside(tester, 'certigo://home?ref=ABC123&share=daily');
      expect(location(router), Routes.home);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.home);
    });

    testWidgets('la navigation interne reste libre', (WidgetTester tester) async {
      final GoRouter router = buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ExternalLinkScope(router: router, child: MaterialApp.router(routerConfig: router)),
      );

      router.go(Routes.accountDeletion);
      await tester.pumpAndSettle();

      expect(location(router), Routes.accountDeletion);
    });
  });

  test('l\'application installe la garde et ignore la route initiale de la plateforme', () {
    File resolve(String relative) {
      for (final String base in <String>['.', 'apps/mobile']) {
        final File file = File('$base/$relative');
        if (file.existsSync()) return file;
      }
      return File(relative);
    }

    final String app = resolve('lib/app/app.dart').readAsStringSync();
    expect(app, contains('return ExternalLinkScope('));
    expect(app, contains('child: MaterialApp.router('));
    expect(
      resolve('lib/app/router.dart').readAsStringSync(),
      contains('overridePlatformDefaultLocation: true'),
    );
  });
}
