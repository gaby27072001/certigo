import 'package:certigo/app/providers.dart';
import 'package:certigo/features/home/application/home_controller.dart';
import 'package:certigo/features/library/presentation/certification_chapters_screen.dart';
import 'package:certigo/features/library/presentation/vendor_catalog_screen.dart';
import 'package:certigo/features/library/presentation/vendor_certifications_screen.dart';
import 'package:certigo/features/path/presentation/cert_picker_sheet.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget tests for the Part-4 library catalogue (vendor → certification →
/// chapters). We override [catalogProvider] / [pathProvider] with deterministic
/// fakes — the same ProviderScope-override pattern the path suite uses to swap
/// repositories — so the screens render against known data with no network.
void main() {
  TrackSummary track(String id, String code, String title, {String level = 'fundamentals'}) =>
      TrackSummary(
        id: id,
        code: code,
        title: title,
        level: level,
        summary: '',
        unitCount: 5,
        lessonCount: 20,
      );

  final List<TrackSummary> fakeCatalog = <TrackSummary>[
    track('az-900', 'AZ-900', 'Azure Fundamentals'),
    track('az-104', 'AZ-104', 'Azure Administrator', level: 'associate'),
    track('sc-900', 'SC-900', 'Security Fundamentals'),
    track('ai-900', 'AI-900', 'AI Fundamentals'),
    track('github-foundations', 'GH-900', 'GitHub Foundations'),
  ];

  group('VendorCatalogScreen', () {
    testWidgets('renders real vendors with counts and showcase "Bientôt" tiles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            catalogProvider.overrideWith((Ref ref) async => fakeCatalog),
            homeDataProvider.overrideWith((Ref ref) async => throw StateError('no home')),
          ],
          child: MaterialApp(
            theme: PrismTheme.light(),
            home: const Scaffold(body: VendorCatalogScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('Microsoft'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      // 4 Microsoft tracks, 1 GitHub track.
      expect(find.text('4 certifications'), findsOneWidget);
      expect(find.text('1 certification'), findsOneWidget);
      // Three showcase vendors, all "Bientôt".
      expect(find.text('Bientôt'), findsNWidgets(3));
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('AWS'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
    });
  });

  group('VendorCertificationsScreen', () {
    Future<void> pumpCerts(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            catalogProvider.overrideWith((Ref ref) async => fakeCatalog),
          ],
          child: const MaterialApp(
            home: VendorCertificationsScreen(vendor: VendorBrand.microsoft),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    }

    testWidgets('groups Microsoft tracks by category and hides other vendors',
        (WidgetTester tester) async {
      await pumpCerts(tester);

      expect(find.text('Azure'), findsOneWidget);
      expect(find.text('Sécurité'), findsOneWidget);
      expect(find.text('Data & IA'), findsOneWidget);
      expect(find.text('AZ-900'), findsOneWidget);
      // GitHub track belongs to another vendor → filtered out.
      expect(find.text('GH-900'), findsNothing);
    });

    testWidgets('search filters the sections', (WidgetTester tester) async {
      await pumpCerts(tester);

      await tester.enterText(find.byType(TextField), 'AZ');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('Azure'), findsOneWidget);
      expect(find.text('AZ-900'), findsOneWidget);
      expect(find.text('Sécurité'), findsNothing);
      expect(find.text('SC-900'), findsNothing);
    });
  });

  group('CertificationChaptersScreen', () {
    LearningPath fakePath() => const LearningPath(
          trackId: 'az-900',
          trackName: 'Fondamentaux Azure',
          exam: 'AZ-900',
          readinessScore: 60,
          readinessTrend7d: 4,
          units: <PathUnit>[
            PathUnit(
              id: 'u1',
              title: 'Concepts du cloud',
              domainId: 'd1',
              status: NodeStatus.completed,
              lessons: <PathLesson>[
                PathLesson(
                  id: 'l1',
                  title: 'Le cloud',
                  status: NodeStatus.completed,
                  estMinutes: 5,
                  masteryPct: 100,
                ),
              ],
            ),
            PathUnit(
              id: 'u2',
              title: 'Architecture Azure',
              domainId: 'd2',
              status: NodeStatus.inProgress,
              lessons: <PathLesson>[
                PathLesson(
                  id: 'l2',
                  title: 'Régions',
                  status: NodeStatus.available,
                  estMinutes: 5,
                  masteryPct: 0,
                ),
              ],
            ),
            PathUnit(
              id: 'u3',
              title: 'Gouvernance',
              domainId: 'd3',
              status: NodeStatus.locked,
              lessons: <PathLesson>[
                PathLesson(
                  id: 'l3',
                  title: 'Coûts',
                  status: NodeStatus.locked,
                  estMinutes: 5,
                  masteryPct: 0,
                ),
              ],
            ),
          ],
          domains: <DomainProgress>[],
        );

    testWidgets('renders chapters with real lock/progress and navigates on start',
        (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          pathProvider('az-900').overrideWith((Ref ref) async => fakePath()),
        ],
      );
      addTearDown(container.dispose);

      final GoRouter router = GoRouter(
        initialLocation: '/chapters',
        routes: <RouteBase>[
          GoRoute(
            path: '/chapters',
            builder: (_, __) => const CertificationChaptersScreen(trackId: 'az-900'),
          ),
          GoRoute(
            path: '/path',
            builder: (_, __) => const Scaffold(body: Center(child: Text('PATH TAB'))),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('CHAPITRE 1'), findsOneWidget);
      expect(find.text('Architecture Azure'), findsOneWidget);
      expect(find.text('Gouvernance'), findsOneWidget);
      // The locked chapter surfaces its unlock hint; the available one, a CTA.
      expect(find.text('Termine le chapitre précédent pour débloquer'), findsOneWidget);
      expect(find.text('Commencer ici'), findsOneWidget);

      await tester.tap(find.text('Commencer ici'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('PATH TAB'), findsOneWidget);
      expect(container.read(activeTrackProvider), 'az-900');
    });
  });

  group('cert_picker_sheet (regression after CertificationCard refactor)', () {
    testWidgets('renders the shared CertificationCard for each track', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            catalogProvider.overrideWith((Ref ref) async => fakeCatalog),
          ],
          child: MaterialApp(
            theme: PrismTheme.light(),
            home: const Scaffold(body: CertPickerSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(CertificationCard), findsWidgets);
      expect(find.text('AZ-900'), findsOneWidget);
      expect(find.text('Azure Fundamentals'), findsOneWidget);
    });
  });
}
