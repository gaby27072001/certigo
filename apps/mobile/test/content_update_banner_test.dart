import 'dart:convert';

import 'package:certigo/app/content/content_update_banner.dart';
import 'package:certigo/app/content/runtime_content_providers.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NeverSource implements PublicContentSource {
  @override
  Future<Result<PublicManifestFetch>> fetchActiveManifest({
    String? ifNoneMatch,
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  }) async =>
      const Err<PublicManifestFetch>(NetworkFailure());

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String releaseId,
    required String publicManifestId,
    required PublicContentFile file,
    String? ifNoneMatch,
  }) async =>
      const Err<PublicContentFileFetch>(NetworkFailure());
}

class _StatusController extends RuntimeContentController {
  _StatusController(RuntimeContentStatus status, RuntimeContentSynchronizer synchronizer)
      : super(
          synchronizer: synchronizer,
          pins: RuntimeContentPinRegistry(),
          syncEngine: SyncEngine(
            store: InMemorySyncQueueStore(),
            sender: (SyncAction _) async => SyncDispatch.success,
          ),
        ) {
    state = status;
  }
}

void main() {
  test('corrupt offline entry is quarantined without blocking runtime sync', () async {
    final SyncAction healthy = SyncAction(
      id: 'healthy',
      kind: 'quizSubmit',
      endpoint: '/quiz/lesson/submit',
      payload: const <String, dynamic>{},
      idempotencyKey: 'healthy',
      createdAt: DateTime.utc(2026),
      ownerId: 'person-1',
    );
    final List<SyncQueueCorruption> quarantined = <SyncQueueCorruption>[];
    final SyncEngine engine = SyncEngine(
      store: JsonSyncQueueStore(
        read: () async => jsonEncode(<dynamic>[
          <String, dynamic>{'id': 42},
          healthy.toJson(),
        ]),
        write: (_) async {},
        quarantine: (SyncQueueCorruption corruption) async {
          quarantined.add(corruption);
          return true;
        },
      ),
      sender: (_) async => SyncDispatch.success,
    );
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: _NeverSource(),
      store: InMemoryRuntimeContentStore(),
      limits: const RuntimeContentLimits(maxAttempts: 1),
      delay: (_) async {},
    );
    final RuntimeContentController controller = RuntimeContentController(
      synchronizer: synchronizer,
      pins: RuntimeContentPinRegistry(),
      syncEngine: engine,
    );
    addTearDown(controller.dispose);
    addTearDown(synchronizer.dispose);
    addTearDown(engine.dispose);

    await expectLater(
      controller.syncNow('person-1'),
      throwsA(isA<RuntimeContentSyncException>()),
    );

    expect(engine.actions.single.id, 'healthy');
    expect(quarantined.single.reason, 'entry-type');
    expect(synchronizer.currentStatus.phase, RuntimeContentPhase.failed);
  });

  testWidgets('runtime content UX stays absent while the feature flag is off', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ContentUpdateBanner())),
      ),
    );

    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('failed update keeps content available and exposes an accessible retry', (
    WidgetTester tester,
  ) async {
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: _NeverSource(),
      store: InMemoryRuntimeContentStore(),
    );
    addTearDown(synchronizer.dispose);
    final _StatusController controller = _StatusController(
      const RuntimeContentStatus(
        phase: RuntimeContentPhase.failed,
        message: 'Mise à jour indisponible. Le contenu actuel est conservé.',
        canRollback: true,
      ),
      synchronizer,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          runtimeContentSyncEnabledProvider.overrideWithValue(true),
          runtimeContentControllerProvider.overrideWith((Ref ref) => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ContentUpdateBanner())),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Mise à jour indisponible. Le contenu actuel est conservé.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Réessayer'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Version précédente'), findsOneWidget);
  });

  testWidgets('download progress is exposed without a blocking dialog', (
    WidgetTester tester,
  ) async {
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: _NeverSource(),
      store: InMemoryRuntimeContentStore(),
    );
    addTearDown(synchronizer.dispose);
    final _StatusController controller = _StatusController(
      const RuntimeContentStatus(
        phase: RuntimeContentPhase.downloading,
        completedFiles: 2,
        totalFiles: 4,
      ),
      synchronizer,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          runtimeContentSyncEnabledProvider.overrideWithValue(true),
          runtimeContentControllerProvider.overrideWith((Ref ref) => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ContentUpdateBanner())),
      ),
    );

    expect(find.text('Mise à jour du contenu 2/4'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('recovery actions remain accessible with large text on a narrow screen', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: _NeverSource(),
      store: InMemoryRuntimeContentStore(),
    );
    addTearDown(synchronizer.dispose);
    final _StatusController controller = _StatusController(
      const RuntimeContentStatus(
        phase: RuntimeContentPhase.failed,
        message: 'Mise à jour indisponible. Le contenu actuel est conservé.',
        canRollback: true,
      ),
      synchronizer,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          runtimeContentSyncEnabledProvider.overrideWithValue(true),
          runtimeContentControllerProvider.overrideWith((Ref ref) => controller),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: ContentUpdateBanner()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Réessayer'), findsOneWidget);
    expect(find.bySemanticsLabel('Version précédente'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
