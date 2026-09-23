import 'dart:async';

import 'package:certigo/app/providers.dart';
import 'package:certigo/features/streak/application/streak_repair_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_streak_repository.dart';
import 'support/fake_user_repository.dart';

/// The client owns half of the repair's idempotency: the server dedupes on
/// `clientRepairId`, so these tests assert on the keys that actually reach the
/// repository. If the controller ever mints a key per tap again, the first test
/// fails; if it replays a spent key, the next two do.
void main() {
  late FakeStreakRepository repo;
  late int meLoads;

  setUp(() {
    repo = FakeStreakRepository();
    meLoads = 0;
  });

  ProviderContainer containerWithKeys() {
    int minted = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        streakRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((Ref ref) async {
          meLoads++;
          return testUserProfile();
        }),
        clientRepairIdGeneratorProvider.overrideWithValue(() => 'key-${++minted}'),
      ],
    );
    addTearDown(container.dispose);
    // The screen is what keeps the auto-disposed controller alive.
    container.listen(streakRepairControllerProvider, (_, __) {});
    return container;
  }

  Future<void> repair(ProviderContainer container) =>
      container.read(streakRepairControllerProvider.notifier).repair();

  List<String> keys() => repo.requests.map((StreakRepairRequest r) => r.clientRepairId).toList();

  group('the idempotency key lives exactly as long as the outcome is unknown', () {
    test('a failed repair keeps its key, and the retry replays it', () async {
      repo
        ..enqueueRepair(const Err<StreakRepairResult>(NetworkFailure.responseTimeout()))
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final ProviderContainer container = containerWithKeys();

      await repair(container);
      await repair(container);

      // The debit may already have been applied when the reply was lost. A new
      // key would be read by the server as a second repair request.
      expect(keys(), <String>['key-1', 'key-1']);
    });

    test('a granted repair spends its key', () async {
      repo
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair))
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final ProviderContainer container = containerWithKeys();

      await repair(container);
      await repair(container);

      expect(keys(), <String>['key-1', 'key-2']);
    });

    test('a refused repair spends its key: a refusal is a ruling, not an unknown', () async {
      repo
        ..enqueueRepair(Success<StreakRepairResult>(refusedRepair('insufficientGems')))
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final ProviderContainer container = containerWithKeys();

      await repair(container);
      await repair(container);

      expect(keys(), <String>['key-1', 'key-2']);
    });

    test('a second tap while the first is in flight sends nothing', () async {
      repo
        ..hold = Completer<void>()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final ProviderContainer container = containerWithKeys();

      final Future<void> first = repair(container);
      await repair(container);
      repo.hold!.complete();
      await first;

      expect(keys(), <String>['key-1']);
    });
  });

  group('the state carries the ruling', () {
    test('in flight, then granted with the server result', () async {
      repo
        ..hold = Completer<void>()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final ProviderContainer container = containerWithKeys();

      final Future<void> pending = repair(container);
      expect(container.read(streakRepairControllerProvider).phase, StreakRepairPhase.repairing);
      repo.hold!.complete();
      await pending;

      final StreakRepairState state = container.read(streakRepairControllerProvider);
      expect(state.phase, StreakRepairPhase.granted);
      expect(state.result?.gemsBalance, 70);
    });

    test('refused keeps the cause; failed keeps the failure', () async {
      repo
        ..enqueueRepair(Success<StreakRepairResult>(refusedRepair('expired')))
        ..enqueueRepair(const Err<StreakRepairResult>(NetworkFailure()));
      final ProviderContainer container = containerWithKeys();

      await repair(container);
      expect(container.read(streakRepairControllerProvider).phase, StreakRepairPhase.refused);
      expect(
        container.read(streakRepairControllerProvider).result?.refusal,
        StreakRepairRefusal.expired,
      );

      await repair(container);
      final StreakRepairState failed = container.read(streakRepairControllerProvider);
      expect(failed.phase, StreakRepairPhase.failed);
      expect(failed.failure, isA<NetworkFailure>());
    });
  });

  group('a ruling makes every surface re-read the server', () {
    test('a refusal re-reads the streak but not the profile', () async {
      repo.enqueueRepair(Success<StreakRepairResult>(refusedRepair('insufficientGems')));
      final ProviderContainer container = containerWithKeys();
      container
        ..listen(streakStatusProvider, (_, __) {})
        ..listen(meProvider, (_, __) {});
      await container.read(streakStatusProvider.future);
      await container.read(meProvider.future);

      await repair(container);
      await container.read(streakStatusProvider.future);
      await container.read(meProvider.future);

      expect(repo.statusCalls, 2, reason: 'the offer must be re-read after any ruling');
      expect(meLoads, 1, reason: 'nothing was charged, so the profile has not moved');
    });

    test('a grant re-reads the streak and the profile that shows the gems', () async {
      repo.enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final ProviderContainer container = containerWithKeys();
      container
        ..listen(streakStatusProvider, (_, __) {})
        ..listen(meProvider, (_, __) {});
      await container.read(streakStatusProvider.future);
      await container.read(meProvider.future);

      await repair(container);
      await container.read(streakStatusProvider.future);
      await container.read(meProvider.future);

      expect(repo.statusCalls, 2);
      expect(meLoads, 2);
    });

    test('a failure re-reads nothing: no ruling, nothing moved that we know of', () async {
      repo.enqueueRepair(const Err<StreakRepairResult>(ServerFailure('down', statusCode: 503)));
      final ProviderContainer container = containerWithKeys();
      container.listen(streakStatusProvider, (_, __) {});
      await container.read(streakStatusProvider.future);

      await repair(container);
      // An invalidation only schedules the rebuild: read the future so a wrong
      // invalidation would actually re-run the provider before we count. Without
      // this line the assertion held even when the controller invalidated.
      await container.read(streakStatusProvider.future);

      expect(repo.statusCalls, 1);
    });

    test('the controller outlives the screen until its ruling lands, then is released', () async {
      repo
        ..hold = Completer<void>()
        ..enqueueRepair(const Success<StreakRepairResult>(grantedRepair));
      final _DisposalLog disposals = _DisposalLog();
      int minted = 0;
      final ProviderContainer container = ProviderContainer(
        observers: <ProviderObserver>[disposals],
        overrides: <Override>[
          streakRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith((Ref ref) async => testUserProfile()),
          clientRepairIdGeneratorProvider.overrideWithValue(() => 'key-${++minted}'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(streakStatusProvider, (_, __) {});
      await container.read(streakStatusProvider.future);
      final ProviderSubscription<StreakRepairState> screen =
          container.listen(streakRepairControllerProvider, (_, __) {});

      final Future<void> pending = container.read(streakRepairControllerProvider.notifier).repair();
      screen.close(); // The learner goes back while the request is in flight.
      await Future<void>.delayed(Duration.zero);

      // Measured on riverpod 2.6.1: without the keep-alive the controller is
      // disposed right here, and its ruling is then applied through a dead ref —
      // tolerated silently today, rejected outright by Riverpod 3.
      expect(
        disposals.controllerDisposed,
        isFalse,
        reason: 'a request in flight must keep its controller alive',
      );

      repo.hold!.complete();
      await pending;
      await container.read(streakStatusProvider.future);
      expect(repo.statusCalls, 2, reason: 'the ruling still refreshes Home');

      await Future<void>.delayed(Duration.zero);
      expect(disposals.controllerDisposed, isTrue, reason: 'and nothing leaks once it has landed');
    });
  });

  test('a fresh key is non-empty and differs from the next one', () {
    final String a = newClientRepairId();
    final String b = newClientRepairId();

    expect(a, isNotEmpty);
    expect(a, isNot(b));
    expect(a, matches(RegExp(r'^[0-9a-f]+-[0-9a-f]+$')));
  });
}

class _DisposalLog extends ProviderObserver {
  bool controllerDisposed = false;

  @override
  void didDisposeProvider(ProviderBase<Object?> provider, ProviderContainer container) {
    if (provider == streakRepairControllerProvider) controllerDisposed = true;
  }
}
