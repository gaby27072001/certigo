import 'dart:async';

import 'package:data/data.dart';
import 'package:test/test.dart';

/// Deterministic, advanceable clock so every retry/retention rule is exact.
class _FakeClock {
  _FakeClock(this._now);

  DateTime _now;

  DateTime call() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// Records every dispatched action and replies with a scripted outcome.
class _RecordingSender {
  _RecordingSender(this._respond);

  final SyncDispatch Function(SyncAction action) _respond;
  final List<SyncAction> calls = <SyncAction>[];

  Future<SyncDispatch> call(SyncAction action) async {
    calls.add(action);
    return _respond(action);
  }

  List<String> get keys => calls.map((SyncAction a) => a.idempotencyKey).toList();
}

class _BlockedLoadStore implements SyncQueueStore {
  _BlockedLoadStore(this.seed);

  final List<SyncAction> seed;
  final Completer<void> loadGate = Completer<void>();
  int loadCalls = 0;
  List<SyncAction> saved = <SyncAction>[];

  @override
  Future<List<SyncAction>> load() async {
    loadCalls++;
    await loadGate.future;
    return List<SyncAction>.of(seed);
  }

  @override
  Future<void> save(List<SyncAction> actions) async {
    saved = List<SyncAction>.of(actions);
  }
}

class _FailingBlockedLoadStore implements SyncQueueStore {
  final Completer<void> loadGate = Completer<void>();

  @override
  Future<List<SyncAction>> load() async {
    await loadGate.future;
    throw StateError('load failed');
  }

  @override
  Future<void> save(List<SyncAction> actions) async {}
}

Future<void> _enqueue(SyncEngine engine, String key) async {
  await engine.enqueue(
    kind: 'quizSubmit',
    endpoint: '/quiz/$key/submit',
    payload: <String, dynamic>{'k': key},
    idempotencyKey: key,
  );
}

void main() {
  group('SyncEngine', () {
    test(
      'dispose closes the status stream when initial loading fails',
      () async {
        final _FailingBlockedLoadStore store = _FailingBlockedLoadStore();
        final SyncEngine engine = SyncEngine(
          store: store,
          sender: (_) async => SyncDispatch.success,
        );
        final Completer<void> streamClosed = Completer<void>();
        engine.status.listen(null, onDone: streamClosed.complete);

        final Future<void> loading = engine.ensureLoaded();
        final Future<void> disposing = engine.dispose();
        store.loadGate.complete();

        await expectLater(loading, throwsStateError);
        await expectLater(disposing, throwsStateError);
        await expectLater(streamClosed.future, completes);
      },
    );

    test('enqueue dedupes a still-pending action by idempotency key', () async {
      final _RecordingSender sender = _RecordingSender(
        (_) => SyncDispatch.success,
      );
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: sender.call,
      );

      await _enqueue(engine, 'k1');
      await _enqueue(engine, 'k1');

      expect(engine.pendingCount, 1);
      await engine.dispose();
    });

    test(
      'a completed action blocks re-enqueue until its retention elapses',
      () async {
        final _FakeClock clock = _FakeClock(DateTime.utc(2026, 1, 1, 12));
        final _RecordingSender sender = _RecordingSender(
          (_) => SyncDispatch.success,
        );
        final SyncEngine engine = SyncEngine(
          store: InMemorySyncQueueStore(),
          sender: sender.call,
          clock: clock.call,
          doneRetention: const Duration(hours: 24),
        );

        await _enqueue(engine, 'k1');
        await engine.flush();
        expect(engine.pendingCount, 0);

        // Still within retention → deduped against the completed action.
        await _enqueue(engine, 'k1');
        expect(engine.pendingCount, 0);

        // Retention elapsed → a fresh pending action is appended.
        clock.advance(const Duration(hours: 25));
        await _enqueue(engine, 'k1');
        expect(engine.pendingCount, 1);

        await engine.dispose();
      },
    );

    test(
      'flush dispatches due actions oldest-first and drains on success',
      () async {
        final _RecordingSender sender = _RecordingSender(
          (_) => SyncDispatch.success,
        );
        final SyncEngine engine = SyncEngine(
          store: InMemorySyncQueueStore(),
          sender: sender.call,
        );

        await _enqueue(engine, 'k1');
        await _enqueue(engine, 'k2');
        await _enqueue(engine, 'k3');
        await engine.flush();

        expect(sender.keys, <String>['k1', 'k2', 'k3']);
        expect(engine.pendingCount, 0);
        await engine.dispose();
      },
    );

    test(
      'a retryable failure keeps the action pending behind a backoff gate',
      () async {
        final _FakeClock clock = _FakeClock(DateTime.utc(2026, 1, 1, 12));
        final _RecordingSender sender = _RecordingSender(
          (_) => SyncDispatch.retryable,
        );
        final SyncEngine engine = SyncEngine(
          store: InMemorySyncQueueStore(),
          sender: sender.call,
          clock: clock.call,
        );

        await _enqueue(engine, 'k1');

        final SyncFlushReport r1 = await engine.flush();
        expect(r1.retried, 1);
        expect(engine.pendingCount, 1);

        // backoff(1) == 2s, so nothing is due yet.
        final SyncFlushReport r2 = await engine.flush();
        expect(r2.dispatched, 0);
        expect(sender.calls.length, 1);

        clock.advance(const Duration(seconds: 2));
        final SyncFlushReport r3 = await engine.flush();
        expect(r3.dispatched, 1);
        expect(sender.calls.length, 2);

        await engine.dispose();
      },
    );

    test(
      'a persistently retryable action dead-letters after maxAttempts',
      () async {
        final _FakeClock clock = _FakeClock(DateTime.utc(2026, 1, 1, 12));
        final _RecordingSender sender = _RecordingSender(
          (_) => SyncDispatch.retryable,
        );
        final SyncEngine engine = SyncEngine(
          store: InMemorySyncQueueStore(),
          sender: sender.call,
          clock: clock.call,
          maxAttempts: 3,
        );

        await _enqueue(engine, 'k1');
        await engine.flush(); // attempt 1 → backoff 2s
        clock.advance(const Duration(seconds: 2));
        await engine.flush(); // attempt 2 → backoff 4s
        clock.advance(const Duration(seconds: 4));
        await engine.flush(); // attempt 3 → dead-lettered

        expect(sender.calls.length, 3);
        expect(engine.pendingCount, 0);
        expect(engine.deadCount, 1);
        await engine.dispose();
      },
    );

    test('a permanent failure dead-letters immediately', () async {
      final _RecordingSender sender = _RecordingSender(
        (_) => SyncDispatch.permanent,
      );
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: sender.call,
      );

      await _enqueue(engine, 'k1');
      final SyncFlushReport report = await engine.flush();

      expect(report.deadLettered, 1);
      expect(sender.calls.length, 1);
      expect(engine.deadCount, 1);
      expect(engine.pendingCount, 0);
      await engine.dispose();
    });

    test('a sender that throws is treated as a transient failure', () async {
      final _FakeClock clock = _FakeClock(DateTime.utc(2026, 1, 1, 12));
      final _RecordingSender sender = _RecordingSender(
        (_) => throw StateError('boom'),
      );
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: sender.call,
        clock: clock.call,
      );

      await _enqueue(engine, 'k1');
      final SyncFlushReport report = await engine.flush();

      expect(report.retried, 1);
      expect(engine.pendingCount, 1);
      await engine.dispose();
    });

    test(
      'a second engine resumes the persisted queue from a shared store',
      () async {
        final InMemorySyncQueueStore store = InMemorySyncQueueStore();
        final _RecordingSender noop = _RecordingSender(
          (_) => SyncDispatch.retryable,
        );
        final SyncEngine first = SyncEngine(store: store, sender: noop.call);
        await _enqueue(first, 'k1');
        await _enqueue(first, 'k2');
        await first.dispose();

        final _RecordingSender sender = _RecordingSender(
          (_) => SyncDispatch.success,
        );
        final SyncEngine second = SyncEngine(store: store, sender: sender.call);
        await second.ensureLoaded();
        expect(second.pendingCount, 2);

        await second.flush();
        expect(sender.keys, <String>['k1', 'k2']);
        await second.dispose();
      },
    );

    test('JsonSyncQueueStore survives across engine instances', () async {
      String? raw;
      JsonSyncQueueStore makeStore() => JsonSyncQueueStore(
            read: () async => raw,
            write: (String s) async {
              raw = s;
            },
          );

      final _RecordingSender noop = _RecordingSender(
        (_) => SyncDispatch.retryable,
      );
      final SyncEngine first = SyncEngine(
        store: makeStore(),
        sender: noop.call,
      );
      await _enqueue(first, 'k1');
      expect(raw, isNotNull);
      await first.dispose();

      final _RecordingSender sender = _RecordingSender(
        (_) => SyncDispatch.success,
      );
      final SyncEngine second = SyncEngine(
        store: makeStore(),
        sender: sender.call,
      );
      await second.ensureLoaded();
      expect(second.pendingCount, 1);

      await second.flush();
      expect(sender.keys, <String>['k1']);
      await second.dispose();
    });

    test('status stream emits the pending count after an enqueue', () async {
      final _RecordingSender sender = _RecordingSender(
        (_) => SyncDispatch.success,
      );
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: sender.call,
      );

      final Future<void> sawPending = expectLater(
        engine.status,
        emitsThrough(
          predicate<SyncStatus>(
            (SyncStatus s) => s.pending == 1,
            'pending == 1',
          ),
        ),
      );
      await _enqueue(engine, 'k1');
      await sawPending;
      await engine.dispose();
    });

    test('concurrent flushes coalesce into a single dispatch', () async {
      final Completer<void> gate = Completer<void>();
      final List<SyncAction> calls = <SyncAction>[];
      Future<SyncDispatch> slow(SyncAction action) async {
        calls.add(action);
        await gate.future;
        return SyncDispatch.success;
      }

      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: slow,
      );
      await _enqueue(engine, 'k1');

      final Future<SyncFlushReport> f1 = engine.flush();
      final Future<SyncFlushReport> f2 = engine.flush();
      expect(identical(f1, f2), isTrue);

      gate.complete();
      final List<SyncFlushReport> reports = await Future.wait(
        <Future<SyncFlushReport>>[f1, f2],
      );

      expect(calls.length, 1);
      expect(reports.first.succeeded, 1);
      await engine.dispose();
    });

    test(
      'enqueue and flush share a blocked first load without losing the new action',
      () async {
        final SyncAction persisted = SyncAction(
          id: 'persisted',
          kind: 'quizSubmit',
          endpoint: '/quiz/persisted/submit',
          payload: const <String, dynamic>{'k': 'persisted'},
          idempotencyKey: 'persisted',
          createdAt: DateTime.utc(2026),
          ownerId: 'unscoped',
        );
        final _BlockedLoadStore store = _BlockedLoadStore(<SyncAction>[
          persisted,
        ]);
        final _RecordingSender sender = _RecordingSender(
          (_) => SyncDispatch.success,
        );
        final SyncEngine engine = SyncEngine(store: store, sender: sender.call);

        final Future<SyncAction> enqueue = engine.enqueue(
          kind: 'quizSubmit',
          endpoint: '/quiz/new/submit',
          payload: const <String, dynamic>{'k': 'new'},
          idempotencyKey: 'new',
        );
        final Future<SyncFlushReport> flush = engine.flush();
        await Future<void>.delayed(Duration.zero);

        expect(store.loadCalls, 1);
        store.loadGate.complete();
        await enqueue;
        await flush;

        expect(store.loadCalls, 1);
        expect(sender.keys, contains('persisted'));
        expect(
          store.saved.map((SyncAction action) => action.idempotencyKey),
          contains('new'),
        );
        expect(
          engine.actions.map((SyncAction action) => action.idempotencyKey),
          contains('new'),
        );
        await engine.dispose();
      },
    );

    test('dispatches only actions owned by the authenticated account', () async {
      var ownerId = 'user-a';
      final _RecordingSender sender = _RecordingSender((_) => SyncDispatch.success);
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: sender.call,
        ownerIdProvider: () => ownerId,
      );

      await _enqueue(engine, 'same-attempt');
      ownerId = 'user-b';
      await _enqueue(engine, 'same-attempt');
      await engine.flush();

      expect(sender.calls.map((SyncAction action) => action.ownerId), <String?>['user-b']);
      expect(engine.pendingCount, 1);

      ownerId = 'user-a';
      await engine.flush();
      expect(
        sender.calls.map((SyncAction action) => action.ownerId),
        <String?>['user-b', 'user-a'],
      );
      await engine.dispose();
    });

    test('quarantines legacy pending actions that have no owner', () async {
      final SyncAction legacy = SyncAction(
        id: 'legacy',
        kind: 'quizSubmit',
        endpoint: '/quiz/legacy/submit',
        payload: const <String, dynamic>{},
        idempotencyKey: 'legacy',
        createdAt: DateTime.utc(2026),
      );
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(<SyncAction>[legacy]),
        sender: (_) async => SyncDispatch.success,
      );

      await engine.ensureLoaded();

      expect(engine.actions.single.isDead, isTrue);
      expect(engine.actions.single.lastError, 'legacy-owner-missing');
      await engine.dispose();
    });

    test('waitForIdle holds sign-out cleanup until the current owner flush completes', () async {
      final Completer<SyncDispatch> dispatch = Completer<SyncDispatch>();
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: (_) => dispatch.future,
      );
      await _enqueue(engine, 'pending-sign-out');

      final Future<SyncFlushReport> flush = engine.flush();
      await Future<void>.delayed(Duration.zero);
      var cleanupReleased = false;
      final Future<void> waiting = engine.waitForIdle().then((_) {
        cleanupReleased = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(cleanupReleased, isFalse);

      dispatch.complete(SyncDispatch.success);
      await flush;
      await waiting;
      expect(cleanupReleased, isTrue);
      await engine.dispose();
    });

    test('aborts the remaining flush when the authenticated owner changes', () async {
      var ownerId = 'user-a';
      final _RecordingSender sender = _RecordingSender((_) {
        ownerId = 'user-b';
        return SyncDispatch.success;
      });
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: sender.call,
        ownerIdProvider: () => ownerId,
      );
      await _enqueue(engine, 'first');
      await _enqueue(engine, 'second');

      ownerId = 'user-a';
      await engine.flush();

      expect(sender.keys, <String>['first']);
      expect(engine.pendingCount, 1);
      await engine.dispose();
    });
  });
}
