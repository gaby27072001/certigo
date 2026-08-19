import 'package:certigo/app/active_track_store.dart';
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

import 'support/fake_user_repository.dart';

/// Widget tests for the Part-4 library catalogue (vendor → certification →
/// chapters). We override [catalogProvider] / [pathProvider] with deterministic
/// fakes — the same ProviderScope-override pattern the path suite uses to swap
/// repositories — so the screens render against known data with no network.
void main() {
  TrackSummary track(
    String id,
    String code,
    String title, {
    String level = 'fundamentals',
    CertificationProvider provider = CertificationProvider.microsoft,
    String family = 'other',
    CertificationContentStatus contentStatus = CertificationContentStatus.available,
  }) {
    final bool hasOfficialMetadata = <String>{
      'AZ-900',
      'AZ-104',
      'AI-900',
      'AI-901',
    }.contains(code);
    final bool learningAvailable =
        contentStatus == CertificationContentStatus.available && code != 'AI-901';
    return TrackSummary(
      id: id,
      code: code,
      title: title,
      level: level,
      summary: '',
      unitCount: 5,
      lessonCount: 20,
      domains: hasOfficialMetadata
          ? <CertificationDomain>[
              CertificationDomain(
                id: 'domain-1',
                name: code == 'AI-901'
                    ? 'Implement AI solutions by using Microsoft Foundry'
                    : 'Describe cloud concepts',
                minWeightPct: 25,
                maxWeightPct: 30,
              ),
            ]
          : const <CertificationDomain>[],
      prerequisites: hasOfficialMetadata ? 'Aucun prérequis formel.' : '',
      studyGuideUrl: hasOfficialMetadata
          ? 'https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/${code.toLowerCase()}'
          : '',
      examUrl: hasOfficialMetadata
          ? 'https://learn.microsoft.com/en-us/credentials/certifications/exams/${code.toLowerCase()}/'
          : '',
      blueprintDate: code == 'AZ-900' ? '2026-07-20' : '2026-04-17',
      lifecycle: code == 'AI-900' ? 'retired' : 'active',
      lifecycleNote: code == 'AI-900'
          ? 'Examen retiré le 30 juin 2026.'
          : code == 'AI-901'
              ? 'Certification active. Parcours Certigo en préparation.'
              : '',
      examDetailsNote: hasOfficialMetadata ? 'Le tarif et la durée peuvent changer.' : '',
      learningAvailable: learningAvailable,
      replacementCode: code == 'AI-900' ? 'AI-901' : '',
      migrationNote: code.startsWith('AI-9')
          ? 'La progression AI-900 reste disponible ; AI-901 est la cible active.'
          : '',
      provider: provider,
      family: family,
      status: code == 'AI-900'
          ? CertificationLifecycleStatus.retired
          : CertificationLifecycleStatus.active,
      contentStatus: contentStatus,
    );
  }

  final List<TrackSummary> fakeCatalog = <TrackSummary>[
    track('az-900', 'AZ-900', 'Azure Fundamentals'),
    track('az-104', 'AZ-104', 'Azure Administrator', level: 'associate'),
    track('sc-900', 'SC-900', 'Security Fundamentals'),
    track('ai-900', 'AI-900', 'AI Fundamentals'),
    track(
      'ai-901',
      'AI-901',
      'Microsoft Azure AI Fundamentals',
      family: 'data-ai',
      contentStatus: CertificationContentStatus.planned,
    ),
    track(
      'github-foundations',
      'GH-900',
      'GitHub Foundations',
      provider: CertificationProvider.github,
    ),
    track(
      'aws-aif-c01',
      'AIF-C01',
      'AWS Certified AI Practitioner',
      provider: CertificationProvider.aws,
      family: 'ai',
      contentStatus: CertificationContentStatus.planned,
    ),
    track(
      'gcp-cloud-digital-leader',
      '',
      'Cloud Digital Leader',
      provider: CertificationProvider.gcp,
      family: 'cloud-foundations',
      contentStatus: CertificationContentStatus.planned,
    ),
  ];

  group('VendorCatalogScreen', () {
    testWidgets('renders multi-cloud providers with counts and one showcase tile', (
      WidgetTester tester,
    ) async {
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
      expect(find.text('AWS'), findsOneWidget);
      expect(find.text('Google Cloud'), findsOneWidget);
      // Five Microsoft tracks and one track for every other catalogued provider.
      expect(find.text('5 certifications'), findsOneWidget);
      expect(find.text('1 certification'), findsNWidgets(3));
      // OpenAI remains the sole showcase provider.
      expect(find.text('Bientôt'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
    });
  });

  group('VendorCertificationsScreen', () {
    Future<void> pumpCerts(
      WidgetTester tester, {
      VendorBrand vendor = VendorBrand.microsoft,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[catalogProvider.overrideWith((Ref ref) async => fakeCatalog)],
          child: MaterialApp(home: VendorCertificationsScreen(vendor: vendor)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    }

    testWidgets('groups Microsoft tracks by category and hides other vendors', (
      WidgetTester tester,
    ) async {
      await pumpCerts(tester);

      expect(find.text('Azure'), findsOneWidget);
      expect(find.text('Sécurité'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Data & IA'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
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

    testWidgets('renders planned AWS certifications without opening an empty path', (
      WidgetTester tester,
    ) async {
      await pumpCerts(tester, vendor: VendorBrand.aws);

      expect(find.text('IA & machine learning'), findsOneWidget);
      expect(find.text('AIF-C01'), findsOneWidget);
      expect(find.text('Parcours à venir'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('renders a neutral GCP badge when no public exam code exists', (
      WidgetTester tester,
    ) async {
      await pumpCerts(tester, vendor: VendorBrand.google);

      expect(find.text('GCP'), findsOneWidget);
      expect(find.text('Cloud Digital Leader'), findsOneWidget);
      expect(find.text('Parcours à venir'), findsOneWidget);
    });

    testWidgets('shows official blueprint domains, links and retirement status', (
      WidgetTester tester,
    ) async {
      await pumpCerts(tester);
      expect(find.text('Référentiel officiel · 2026-07-20'), findsOneWidget);

      await tester.tap(find.text('Référentiel officiel · 2026-07-20'));
      await tester.pumpAndSettle();

      expect(find.text('Describe cloud concepts'), findsOneWidget);
      expect(find.text('25–30%'), findsOneWidget);
      expect(find.text('Guide officiel Microsoft Learn'), findsOneWidget);
      expect(find.textContaining('Le tarif et la durée peuvent changer.'), findsOneWidget);
      expect(find.byTooltip('Copier le lien Guide officiel Microsoft Learn'), findsOneWidget);

      await tester.tap(find.text('Référentiel officiel · 2026-07-20'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Examen retiré · parcours archivé'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Examen retiré · parcours archivé'), findsOneWidget);
    });

    testWidgets('keeps AI-901 visible but blocks learning navigation until content exists', (
      WidgetTester tester,
    ) async {
      await pumpCerts(tester);
      await tester.scrollUntilVisible(
        find.text('AI-901'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('AI-901'));
      await tester.pumpAndSettle();

      final Finder cardFinder = find.ancestor(
        of: find.text('AI-901'),
        matching: find.byType(CertificationCard),
      );
      final CertificationCard card = tester.widget<CertificationCard>(cardFinder);
      expect(card.onTap, isNull);
      expect(card.statusLabel, 'Parcours à venir');
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

    testWidgets('renders chapters with real lock/progress and navigates on start', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          activeTrackStoreProvider.overrideWithValue(
            InMemoryActiveTrackStore.synced('az-900'),
          ),
          activeTrackOwnerIdProvider.overrideWithValue('user-1'),
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(profile: testUserProfile(activeTrackId: 'az-900')),
          ),
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
      expect(container.read(activeTrackProvider).asData?.value, 'az-900');
    });
  });

  group('cert_picker_sheet (regression after CertificationCard refactor)', () {
    testWidgets('renders the shared CertificationCard for each track', (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          activeTrackStoreProvider.overrideWithValue(
            InMemoryActiveTrackStore.synced('az-900'),
          ),
          activeTrackOwnerIdProvider.overrideWithValue('user-1'),
          catalogProvider.overrideWith((Ref ref) async => fakeCatalog),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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
      expect(find.text('AIF-C01'), findsNothing);
      expect(find.text('Cloud Digital Leader'), findsNothing);
      expect(find.text('Bientôt'), findsOneWidget);

      await tester.ensureVisible(find.text('AI-901'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI-901'));
      await tester.pump();
      expect(container.read(activeTrackProvider).asData?.value, 'az-900');
      expect(container.read(activeTrackProvider).asData?.value, 'az-900');
    });
  });
}
