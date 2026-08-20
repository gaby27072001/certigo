import 'dart:async';

import 'package:certigo/app/active_track_store.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/app/router.dart';
import 'package:certigo/features/home/application/home_controller.dart';
import 'package:certigo/features/onboarding/application/onboarding_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_user_repository.dart';

class _RecordingPathRepository implements PathRepository {
  final List<String> calls = <String>[];

  @override
  Future<Result<LearningPath>> getPath(String trackId) async {
    calls.add(trackId);
    return Success<LearningPath>(
      LearningPath(
        trackId: trackId,
        trackName: trackId,
        exam: trackId.toUpperCase(),
        readinessScore: 0,
        readinessTrend7d: 0,
        units: const <PathUnit>[],
        domains: const <DomainProgress>[],
      ),
    );
  }
}

class _FailingWriteActiveTrackStore implements ActiveTrackStore {
  _FailingWriteActiveTrackStore(this.record);

  ActiveTrackRecord? record;

  @override
  ActiveTrackRecord? read() => record;

  @override
  Future<void> write(ActiveTrackRecord record) async {
    throw StateError('write failed');
  }

  @override
  Future<void> clear() async {
    record = null;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final TargetCertification certification in availableTargetCertifications) {
    test('Home resolves ${certification.trackId} without AZ-900 fallback', () async {
      final InMemoryActiveTrackStore store = InMemoryActiveTrackStore.synced(certification.trackId);
      final FakeUserRepository users = FakeUserRepository(
        profile: testUserProfile(activeTrackId: 'az-900'),
      );
      final _RecordingPathRepository paths = _RecordingPathRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          activeTrackStoreProvider.overrideWithValue(store),
          activeTrackOwnerIdProvider.overrideWithValue('user-1'),
          userRepositoryProvider.overrideWithValue(users),
          pathRepositoryProvider.overrideWithValue(paths),
        ],
      );
      addTearDown(container.dispose);

      final HomeData home = await container.read(homeDataProvider.future);

      expect(home.path.trackId, certification.trackId);
      expect(paths.calls, <String>[certification.trackId]);
    });

    testWidgets('Path opens ${certification.trackId} without AZ-900 fallback', (
      WidgetTester tester,
    ) async {
      final _RecordingPathRepository paths = _RecordingPathRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          activeTrackStoreProvider.overrideWithValue(
            InMemoryActiveTrackStore.synced(certification.trackId),
          ),
          activeTrackOwnerIdProvider.overrideWithValue('user-1'),
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(profile: testUserProfile(activeTrackId: 'az-900')),
          ),
          pathRepositoryProvider.overrideWithValue(paths),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: PrismTheme.light(), home: const ActivePathScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(paths.calls, <String>[certification.trackId]);
    });
  }

  test('missing local and remote selection fails explicitly without requesting AZ-900', () async {
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: null),
    );
    final _RecordingPathRepository paths = _RecordingPathRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(InMemoryActiveTrackStore()),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
        pathRepositoryProvider.overrideWithValue(paths),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(homeDataProvider.future),
      throwsA(isA<MissingActiveTrackException>()),
    );
    expect(paths.calls, isEmpty);
  });

  test('selection survives a provider-container restart and is sent to the API', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SharedPreferencesActiveTrackStore store = SharedPreferencesActiveTrackStore(preferences);
    final FakeUserRepository users = FakeUserRepository();
    final ProviderContainer first = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );

    final ActiveTrackSaveResult result =
        await first.read(activeTrackProvider.notifier).select('sc-900');
    expect(result.status, ActiveTrackSaveStatus.synced);
    expect(users.setActiveTrackCalls, <String>['sc-900']);
    expect(users.expectedTrackCalls, <String?>[null]);
    first.dispose();

    final ProviderContainer restarted = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(
          SharedPreferencesActiveTrackStore(await SharedPreferences.getInstance()),
        ),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(restarted.dispose);

    expect(await restarted.read(activeTrackProvider.future), 'sc-900');
  });

  test('remote profile restores the local cache when this device has no selection', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(
          FakeUserRepository(profile: testUserProfile(activeTrackId: 'dp-900')),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(activeTrackProvider.future), 'dp-900');
    expect(container.read(activeTrackProvider).asData?.value, 'dp-900');
    expect(store.read()?.trackId, 'dp-900');
  });

  test('offline selection stays local and persists the real API mutation', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore();
    final FakeUserRepository users = FakeUserRepository(
      getFailure: const NetworkFailure(),
      setFailure: const NetworkFailure(),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);

    final ActiveTrackSaveResult result =
        await container.read(activeTrackProvider.notifier).select('az-104');

    expect(result.status, ActiveTrackSaveStatus.queued);
    expect(container.read(activeTrackProvider).asData?.value, 'az-104');
    expect(store.read()?.trackId, 'az-104');
    expect(store.read()?.isPending, isTrue);
    expect(store.read()?.pendingBaseTrackId, isNull);

    users
      ..getFailure = null
      ..setFailure = null;
    await container.read(activeTrackProvider.notifier).syncPending();

    expect(store.read()?.trackId, 'az-104');
    expect(store.read()?.isPending, isFalse);
  });

  test('a pending selection resumes after a process restart', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore(
      ActiveTrackRecord.pending(
        trackId: 'sc-900',
        ownerId: 'user-1',
        mutationId: 'pending-1',
        baseTrackId: null,
      ),
    );
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: null),
    );
    final ProviderContainer restarted = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(restarted.dispose);

    expect(await restarted.read(activeTrackProvider.future), 'sc-900');
    await restarted.read(activeTrackProvider.notifier).syncPending();

    expect(users.setActiveTrackCalls, <String>['sc-900']);
    expect(users.expectedTrackCalls, <String?>[null]);
    expect(store.read()?.isPending, isFalse);
  });

  test('multiple offline choices coalesce to the latest selection', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore();
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: null),
      setFailure: const NetworkFailure(),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeTrackProvider.notifier).select('dp-900');
    await container.read(activeTrackProvider.notifier).select('sc-900');
    expect(store.read()?.trackId, 'sc-900');
    expect(store.read()?.pendingBaseTrackId, isNull);

    users.setFailure = null;
    await container.read(activeTrackProvider.notifier).syncPending();

    expect(container.read(activeTrackProvider).asData?.value, 'sc-900');
    expect(users.setActiveTrackCalls.last, 'sc-900');
    expect(store.read()?.isPending, isFalse);
  });

  test('ambiguous predecessor commit rebases and preserves the latest queued choice', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore(
      ActiveTrackRecord.pending(
        trackId: 'sc-900',
        ownerId: 'user-1',
        mutationId: 'pending-b',
        baseTrackId: 'dp-900',
      ),
    );
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: 'dp-900'),
      setFailure: const NetworkFailure(),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeTrackProvider.future), 'sc-900');

    await container.read(activeTrackProvider.notifier).select('az-104');
    expect(store.read()?.pendingPredecessors, <String>['sc-900']);

    users
      ..setFailure = null
      ..profile = testUserProfile(activeTrackId: 'sc-900');
    await container.read(activeTrackProvider.notifier).syncPending();

    expect(users.expectedTrackCalls.last, 'sc-900');
    expect(container.read(activeTrackProvider).asData?.value, 'az-104');
    expect(store.read()?.trackId, 'az-104');
    expect(store.read()?.isPending, isFalse);
  });

  test('a pending selection is discarded when another account authenticates', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore(
      ActiveTrackRecord.pending(
        trackId: 'sc-900',
        ownerId: 'user-a',
        mutationId: 'pending-a',
        baseTrackId: null,
      ),
    );
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: null),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-b'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeTrackProvider.notifier).syncPending();

    expect(users.setActiveTrackCalls, isEmpty);
    expect(store.read(), isNull);
  });

  test('a newly authenticated owner revalidates a synced cached track', () async {
    final StateProvider<String?> owner = StateProvider<String?>((Ref ref) => 'user-a');
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore.synced(
      'dp-900',
      ownerId: 'user-a',
    );
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(id: 'user-b', activeTrackId: 'sc-900'),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWith((Ref ref) => ref.watch(owner)),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeTrackProvider.future), 'dp-900');

    container.read(owner.notifier).state = 'user-b';
    await Future<void>.delayed(Duration.zero);

    expect(await container.read(activeTrackProvider.future), 'sc-900');
    expect(store.read()?.ownerId, 'user-b');
    expect(store.read()?.trackId, 'sc-900');
  });

  test('clearing an account removes its cached active track', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore.synced('sc-900');
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeTrackProvider.future), 'sc-900');

    await container.read(activeTrackProvider.notifier).clear();

    expect(container.read(activeTrackProvider).asData?.value, isNull);
    expect(store.read(), isNull);
  });

  test('session expiry keeps the pending selection until reauthentication', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore.synced('dp-900');
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: 'dp-900'),
      setFailure: const AuthFailure(),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeTrackProvider.future), 'dp-900');

    final ActiveTrackSaveResult result =
        await container.read(activeTrackProvider.notifier).select('sc-900');

    expect(result.status, ActiveTrackSaveStatus.rejected);
    expect(container.read(activeTrackProvider).asData?.value, 'sc-900');
    expect(store.read()?.trackId, 'sc-900');
    expect(store.read()?.pendingBaseTrackId, 'dp-900');

    users.setFailure = null;
    await container.read(activeTrackProvider.notifier).syncPending();
    expect(store.read()?.isPending, isFalse);
    expect(users.expectedTrackCalls.last, 'dp-900');
  });

  test('server conflict reconciles the cache instead of overwriting another device', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore.synced('dp-900');
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: 'sc-900'),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeTrackProvider.future), 'dp-900');

    final ActiveTrackSaveResult result =
        await container.read(activeTrackProvider.notifier).select('az-104');

    expect(result.status, ActiveTrackSaveStatus.rejected);
    expect(users.expectedTrackCalls, <String?>['dp-900']);
    expect(container.read(activeTrackProvider).asData?.value, 'sc-900');
    expect(store.read()?.trackId, 'sc-900');
    expect(store.read()?.isPending, isFalse);
  });

  test('overlapping selections cannot let an older request overwrite newer state', () async {
    final Completer<Result<UserProfile>> firstRequest = Completer<Result<UserProfile>>();
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore.synced('dp-900');
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: 'dp-900'),
      onSetActiveTrack: (_, __) => firstRequest.future,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeTrackProvider.future), 'dp-900');

    final Future<ActiveTrackSaveResult> first =
        container.read(activeTrackProvider.notifier).select('sc-900');
    await Future<void>.delayed(Duration.zero);
    final ActiveTrackSaveResult overlapping =
        await container.read(activeTrackProvider.notifier).select('az-104');
    firstRequest.complete(
      Success<UserProfile>(testUserProfile(activeTrackId: 'sc-900')),
    );

    expect(overlapping.status, ActiveTrackSaveStatus.rejected);
    expect((await first).status, ActiveTrackSaveStatus.synced);
    expect(container.read(activeTrackProvider).asData?.value, 'sc-900');
    expect(store.read()?.trackId, 'sc-900');
  });

  test('explicit sign-out waits for an in-flight selection before clearing it', () async {
    final Completer<Result<UserProfile>> request = Completer<Result<UserProfile>>();
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore.synced('dp-900');
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: 'dp-900'),
      onSetActiveTrack: (_, __) => request.future,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeTrackProvider.future), 'dp-900');

    final Future<ActiveTrackSaveResult> selection =
        container.read(activeTrackProvider.notifier).select('sc-900');
    await Future<void>.delayed(Duration.zero);
    final Future<void> clearing = container.read(activeTrackProvider.notifier).clear();
    request.complete(const Err<UserProfile>(AuthFailure()));

    expect((await selection).status, ActiveTrackSaveStatus.rejected);
    await clearing;
    expect(store.read(), isNull);
    expect(container.read(activeTrackProvider).asData?.value, isNull);
  });

  test('failed 409 reconciliation retains the pending mutation for a later retry', () async {
    final InMemoryActiveTrackStore store = InMemoryActiveTrackStore(
      ActiveTrackRecord.pending(
        trackId: 'az-104',
        ownerId: 'user-1',
        mutationId: 'conflict-pending',
        baseTrackId: 'dp-900',
      ),
    );
    final FakeUserRepository users = FakeUserRepository(
      profile: testUserProfile(activeTrackId: 'sc-900'),
      getFailure: const NetworkFailure(),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeTrackProvider.notifier).syncPending();

    expect(store.read()?.pendingMutationId, 'conflict-pending');
    expect(store.read()?.trackId, 'az-104');
  });

  test('failed reconciliation persistence keeps the original pending record', () async {
    final void Function(FlutterErrorDetails)? previousHandler = FlutterError.onError;
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousHandler);
    final _FailingWriteActiveTrackStore store = _FailingWriteActiveTrackStore(
      ActiveTrackRecord.pending(
        trackId: 'az-104',
        ownerId: 'user-1',
        mutationId: 'persist-failure',
        baseTrackId: 'dp-900',
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(store),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        userRepositoryProvider.overrideWithValue(
          FakeUserRepository(profile: testUserProfile(activeTrackId: 'sc-900')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeTrackProvider.notifier).syncPending();

    expect(store.read()?.pendingMutationId, 'persist-failure');
    expect(store.read()?.trackId, 'az-104');
    expect(reported, hasLength(1));
  });
}
