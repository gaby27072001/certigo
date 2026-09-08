import 'dart:typed_data';

import 'package:certigo/features/manager/application/manager_models.dart';
import 'package:certigo/features/manager/application/manager_providers.dart';
import 'package:certigo/features/manager/application/manager_repository.dart';
import 'package:certigo/features/manager/presentation/manager_portal_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  const ManagerOrganizationContext manager = ManagerOrganizationContext(
    organizationId: FixtureManagerPortalRepository.fixtureOrganizationId,
    organizationName: 'Northstar Learning',
    role: ManagerOrganizationRole.manager,
  );

  Widget host({
    ManagerOrganizationContext? organization = manager,
    ManagerPortalRepository? repository,
    Locale locale = const Locale('fr'),
  }) {
    return ProviderScope(
      overrides: <Override>[
        managerOrganizationContextProvider.overrideWithValue(organization),
        if (repository != null) managerPortalRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: PrismTheme.light(),
        home: const ManagerPortalScreen(
          organizationId: FixtureManagerPortalRepository.fixtureOrganizationId,
        ),
      ),
    );
  }

  testWidgets('renders aggregate dashboard and suppression notice on desktop', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    expect(find.byType(PrismLoadingView), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Pilotage de la formation'), findsOneWidget);
    expect(find.text('42.5 h'), findsOneWidget);
    expect(find.text('Masqué · cohorte < 5'), findsOneWidget);
    expect(find.textContaining('Aucune identité'), findsOneWidget);
    expect(find.byKey(const Key('manager-rail')), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('uses compact navigation and localizes labels in English', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.text('Learning management'), findsOneWidget);
    expect(find.text('Cohort history'), findsOneWidget);
    expect(find.byKey(const Key('manager-rail')), findsNothing);
  });

  testWidgets(
    'learner and cross-tenant contexts receive the same unavailable surface',
    (WidgetTester tester) async {
      const ManagerOrganizationContext learner = ManagerOrganizationContext(
        organizationId: FixtureManagerPortalRepository.fixtureOrganizationId,
        organizationName: 'Northstar Learning',
        role: ManagerOrganizationRole.learner,
      );
      await tester.pumpWidget(host(organization: learner));
      expect(find.text('Ressource indisponible'), findsOneWidget);

      const ManagerOrganizationContext otherTenant = ManagerOrganizationContext(
        organizationId: 'org-other',
        organizationName: 'Other',
        role: ManagerOrganizationRole.owner,
      );
      await tester.pumpWidget(host(organization: otherTenant));
      expect(find.text('Ressource indisponible'), findsOneWidget);
    },
  );

  testWidgets('covers members assignments exports audit and accessibility', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Membres'));
    await tester.pumpAndSettle();
    expect(find.text('Membre 7A2'), findsOneWidget);
    expect(find.textContaining('acquis individuel'), findsOneWidget);

    await tester.tap(find.text('Assignations'));
    await tester.pumpAndSettle();
    expect(find.text('Contrat backend en attente'), findsOneWidget);

    await tester.tap(find.text('Exports'));
    await tester.pumpAndSettle();
    expect(find.text('Indisponible'), findsNWidgets(2));

    await tester.tap(find.text('Audit'));
    await tester.pumpAndSettle();
    expect(find.text('Bloqué par la policy'), findsOneWidget);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('renders empty and error states', (WidgetTester tester) async {
    await tester.pumpWidget(host(repository: const _EmptyRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Aucune donnée agrégée'), findsOneWidget);

    await tester.pumpWidget(host(repository: const _FailingRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('renders incomplete aggregates as unknown without inventing values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(repository: const _IncompleteMetricRepository()));
    await tester.pumpAndSettle();

    expect(find.text('99.0 h'), findsOneWidget);
    expect(find.text('Inconnu'), findsNWidgets(3));
    expect(find.textContaining('Inconnu complétions'), findsOneWidget);
  });

  testWidgets('matches the manager dashboard golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      _expectManagerDashboardStructure(tester);
    } finally {
      semantics.dispose();
    }
    await _expectManagerGolden(
      find.byType(ManagerPortalScreen),
      'goldens/manager_dashboard.png',
    );
  });

  test('manager golden contract rejects a removed destination', () {
    expect(
      () => _expectRailContract(
        _managerRailLabels.sublist(0, _managerRailLabels.length - 1),
        _managerRailIcons,
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  test('manager golden contract rejects a removed icon', () {
    expect(
      () => _expectRailContract(
        _managerRailLabels,
        _managerRailIcons.sublist(0, _managerRailIcons.length - 1),
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  test('manager golden contract rejects changed text', () {
    expect(
      () => _expectRailContract(
        <String>['Accueil', ..._managerRailLabels.skip(1)],
        _managerRailIcons,
      ),
      throwsA(isA<TestFailure>()),
    );
  });
}

/// Covers the measured 0.69% Linux raster drift with only 0.01% headroom.
const double _managerGoldenDiffTolerance = 0.007;

const List<String> _managerRailLabels = <String>[
  'Tableau de bord',
  'Membres',
  'Équipes',
  'Assignations',
  'Exports',
  'Audit',
];

const List<IconData> _managerRailIcons = <IconData>[
  Icons.dashboard_rounded,
  Icons.group_outlined,
  Icons.groups_outlined,
  Icons.assignment_outlined,
  Icons.download_outlined,
  Icons.policy_outlined,
];

void _expectManagerDashboardStructure(WidgetTester tester) {
  final Finder rail = find.byKey(const Key('manager-rail'));
  expect(rail, findsOneWidget);
  expect(tester.getSize(rail).width, 264);
  final PrismColorScheme colors = tester.element(rail).prism;

  final List<String> labels = <String>[];
  final List<IconData> icons = <IconData>[];
  for (int index = 0; index < _managerRailLabels.length; index += 1) {
    final String label = _managerRailLabels[index];
    final Finder text = find.descendant(of: rail, matching: find.text(label));
    expect(text, findsOneWidget);

    final Finder destination = find.ancestor(
      of: text,
      matching: find.byType(AnimatedContainer),
    );
    expect(destination, findsOneWidget);
    expect(tester.getSize(destination).height, 52);

    final AnimatedContainer destinationWidget = tester.widget<AnimatedContainer>(destination);
    final BoxDecoration decoration = destinationWidget.decoration! as BoxDecoration;
    final Icon icon = tester.widget<Icon>(
      find.descendant(of: destination, matching: find.byType(Icon)),
    );
    final Text labelWidget = tester.widget<Text>(text);
    expect(decoration.color, index == 0 ? colors.primarySoft : Colors.transparent);
    expect(icon.color, index == 0 ? colors.primary : colors.textSecondary);
    expect(labelWidget.style?.color, index == 0 ? colors.primary : colors.textSecondary);

    labels.add(labelWidget.data!);
    icons.add(icon.icon!);

    final Semantics semantics = tester.widget<Semantics>(
      find.ancestor(
        of: text,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics &&
              widget.properties.label == label &&
              widget.properties.button == true,
        ),
      ),
    );
    expect(semantics.properties.label, label);
    expect(semantics.properties.button, isTrue);
    expect(semantics.properties.selected, index == 0);
  }
  _expectRailContract(labels, icons);

  expect(find.text('Pilotage de la formation'), findsOneWidget);
  expect(find.text('Northstar Learning'), findsOneWidget);
  expect(find.text('42.5 h'), findsOneWidget);
  expect(find.textContaining('42.5 h · 31 complétions'), findsOneWidget);
  expect(find.text('18 %'), findsOneWidget);
  expect(find.text('31'), findsOneWidget);
  expect(find.text('67 %'), findsOneWidget);
  expect(find.text('Historique des cohortes'), findsOneWidget);
  expect(find.text('Semaine 33'), findsOneWidget);
  expect(find.text('Semaine 34'), findsOneWidget);
  expect(find.text('Masqué · cohorte < 5'), findsOneWidget);
  expect(find.textContaining('Aucune identité'), findsOneWidget);
}

void _expectRailContract(List<String> labels, List<IconData> icons) {
  expect(labels, _managerRailLabels);
  expect(icons, _managerRailIcons);
}

Future<void> _expectManagerGolden(Finder finder, String goldenPath) async {
  final GoldenFileComparator previous = goldenFileComparator;
  if (previous is! LocalFileComparator) {
    await expectLater(finder, matchesGoldenFile(goldenPath));
    return;
  }

  goldenFileComparator = _ManagerGoldenComparator(previous.basedir);
  try {
    await expectLater(finder, matchesGoldenFile(goldenPath));
  } finally {
    goldenFileComparator = previous;
  }
}

class _ManagerGoldenComparator extends LocalFileComparator {
  _ManagerGoldenComparator(Uri basedir) : super(Uri.parse('$basedir/manager_portal_test.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _managerGoldenDiffTolerance) {
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

class _EmptyRepository implements ManagerPortalRepository {
  const _EmptyRepository();

  @override
  Future<Result<ManagerPortalData>> loadPortal(
    ManagerOrganizationContext context,
  ) async {
    return Success<ManagerPortalData>(
      ManagerPortalData(
        organizationId: context.organizationId,
        members: const <ManagerMemberSummary>[],
        teams: const <ManagerTeamSummary>[],
        metrics: const <ManagerMetricSummary>[],
        assignment: const ManagerAssignmentSummary(
          availability: ManagerAssignmentAvailability.contractPending,
          canManage: true,
        ),
        exports: const <ManagerExportOption>[],
        audit: const <ManagerAuditSummary>[],
      ),
    );
  }
}

class _FailingRepository implements ManagerPortalRepository {
  const _FailingRepository();

  @override
  Future<Result<ManagerPortalData>> loadPortal(
    ManagerOrganizationContext context,
  ) async {
    return const Err<ManagerPortalData>(NetworkFailure());
  }
}

class _IncompleteMetricRepository implements ManagerPortalRepository {
  const _IncompleteMetricRepository();

  @override
  Future<Result<ManagerPortalData>> loadPortal(
    ManagerOrganizationContext context,
  ) async {
    return Success<ManagerPortalData>(
      ManagerPortalData(
        organizationId: context.organizationId,
        members: const <ManagerMemberSummary>[],
        teams: const <ManagerTeamSummary>[],
        metrics: const <ManagerMetricSummary>[
          ManagerMetricSummary(
            periodLabel: 'Semaine 33',
            suppressed: false,
            learningHours: 99,
          ),
        ],
        assignment: const ManagerAssignmentSummary(
          availability: ManagerAssignmentAvailability.contractPending,
          canManage: true,
        ),
        exports: const <ManagerExportOption>[],
        audit: const <ManagerAuditSummary>[],
      ),
    );
  }
}
