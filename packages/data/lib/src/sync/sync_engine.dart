import 'dart:async';

import 'backoff.dart';
import 'sync_action.dart';
import 'sync_dispatcher.dart';
import 'sync_queue_store.dart';

/// Snapshot of the queue's health, emitted on [SyncEngine.status].
class SyncStatus {
  const SyncStatus({required this.pending, required this.dead, required this.syncing});

  /// Number of actions awaiting (or backing off before) dispatch.
  final int pending;

  /// Number of dead-lettered (permanently failed) actions.
  final int dead;

  /// Whether a flush is currently running.
  final bool syncing;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.pending == pending &&
      other.dead == dead &&
      other.syncing == syncing;

  @override
  int get hashCode => Object.hash(pending, dead, syncing);

  @override
  String toString() =>
      'SyncStatus(pending: $pending, dead: $dead, syncing: $syncing)';
}

/// Result of a single [SyncEngine.flush] pass.
class SyncFlushReport {
  const SyncFlushReport({
    required this.dispatched,
    required this.succeeded,
    required this.retried,
    required this.deadLettered,
    required this.pendingRemaining,
  });

  /// Total actions the engine attempted to send this pass.
  final int dispatched;

  /// How many succeeded.
  final int succeeded;

  /// How many failed transiently and were rescheduled with backoff.
  final int retried;

  /// How many were dead-lettered (permanent failure or retries exhausted).
  final int deadLettered;

  /// Pending actions still queued after the pass (some may be backing off).
  final int pendingRemaining;

  /// True when there was nothing due to dispatch.
  bool get isIdle => dispatched == 0;

  @override
  String toString() =>
      'SyncFlushReport(dispatched: $dispatched, succeeded: $succeeded, '
      'retried: $retried, deadLettered: $deadLettered, pendingRemaining: $pendingRemaining)';
}

/// Pure, deterministic offline action queue.
///
/// The engine owns NO timers, connectivity listeners or HTTP. It exposes a
/// single [flush] entry point that the app calls (on reconnect, on resume, on
/// app start). All time comes from the injected [clock], so every retry and
/// retention rule is exactly unit-testable.
///
/// Guarantees:
/// * **Idempotent enqueue** — re-enqueuing the same [idempotencyKey] while a
///   matching action is still live (pending, or done within retention) is a
///   no-op, so a double-tap or a resume can't duplicate work.
/// * **At-least-once dispatch with server dedupe** — the server collapses
///   replays by idempotency key, so at-least-once is effectively exactly-once.
/// * **Bounded retries** — transient failures back off; after [maxAttempts]
///   total attempts an action is dead-lettered instead of spinning forever.
/// * **Coalesced flushes** — concurrent [flush] calls share one in-flight pass,
///   so an action is never dispatched twice in parallel.
/// * **Self-pruning** — done/dead actions are dropped after their retention
///   windows so storage stays bounded.
class SyncEngine {
  SyncEngine({
    required SyncQueueStore store,
    required SyncSender sender,
    DateTime Function()? clock,
    BackoffPolicy? backoff,
    String Function()? idGenerator,
    this.maxAttempts = 6,
    this.doneRetention = const Duration(hours: 24),
    this.deadRetention = const Duration(days: 7),
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1'),
       _store = store,
       _sender = sender,
       _clock = clock ?? DateTime.now,
       _backoff = backoff ?? exponentialBackoff(),
       _idGenerator = idGenerator;

  final SyncQueueStore _store;
  final SyncSender _sender;
  final DateTime Function() _clock;
  final BackoffPolicy _backoff;
  final String Function()? _idGenerator;

  /// Total dispatch attempts before an action is dead-lettered.
  final int maxAttempts;

  /// How long a `done` action is retained (so restarts can still dedupe).
  final Duration doneRetention;

  /// How long a `dead` action is retained for diagnostics.
  final Duration deadRetention;

  final List<SyncAction> _queue = <SyncAction>[];
  bool _loaded = false;
  bool _disposed = false;
  int _idSeq = 0;
  final StreamController<SyncStatus> _status =
      StreamController<SyncStatus>.broadcast();
  Future<void>? _loadFuture;
  Future<void> _persistTail = Future<void>.value();
  Future<SyncFlushReport>? _inFlight;
  Future<void>? _disposing;

  /// Health updates for UI badges ("3 leçons en attente de synchronisation").
  Stream<SyncStatus> get status => _status.stream;

  /// Count of pending actions currently queued.
  int get pendingCount => _queue.where((SyncAction a) => a.isPending).length;

  /// Count of dead-lettered actions currently queued.
  int get deadCount => _queue.where((SyncAction a) => a.isDead).length;

  /// Immutable view of the queue (for diagnostics/tests).
  List<SyncAction> get actions => List<SyncAction>.unmodifiable(_queue);

  /// Lazily loads the persisted queue exactly once.
  Future<void> ensureLoaded() {
    _ensureActive();
    if (_loaded) return Future<void>.value();
    final Future<void>? running = _loadFuture;
    if (running != null) return running;
    final Future<void> loading = _load();
    _loadFuture = loading;
    return loading;
  }

  Future<void> _load() async {
    try {
      final List<SyncAction> persisted = await _store.load();
      _queue
        ..clear()
        ..addAll(persisted);
      _loaded = true;
      _emit();
    } finally {
      _loadFuture = null;
    }
  }

  /// Enqueues an action, deduping by [idempotencyKey].
  ///
  /// Returns the live action for the key: either a pre-existing one (so the
  /// caller sees the dedupe) or the newly-appended one.
  Future<SyncAction> enqueue({
    required String kind,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    _ensureActive();
    await ensureLoaded();
    final SyncAction? live = _findLiveByKey(idempotencyKey);
    if (live != null) return live;

    final SyncAction action = SyncAction(
      id: _nextId(),
      kind: kind,
      endpoint: endpoint,
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: _clock(),
    );
    _queue.add(action);
    await _persist();
    _emit();
    return action;
  }

  /// Dispatches every due pending action, oldest first.
  ///
  /// Concurrent calls coalesce into the single in-flight pass.
  Future<SyncFlushReport> flush() {
    _ensureActive();
    final Future<SyncFlushReport>? running = _inFlight;
    if (running != null) return running;
    final Future<SyncFlushReport> pass = _flush().whenComplete(
      () => _inFlight = null,
    );
    _inFlight = pass;
    return pass;
  }

  Future<SyncFlushReport> _flush() async {
    await ensureLoaded();
    _emit(syncing: true);

    final DateTime now = _clock();
    final List<String> dueIds = _queue
        .where((SyncAction a) => a.isDue(now))
        .map((SyncAction a) => a.id)
        .toList();

    var dispatched = 0;
    var succeeded = 0;
    var retried = 0;
    var deadLettered = 0;

    for (final String id in dueIds) {
      final int index = _indexOf(id);
      if (index < 0) continue;
      final SyncAction current = _queue[index];
      // Re-check: a coalesced caller or an earlier iteration may have changed it.
      if (!current.isDue(_clock())) continue;

      dispatched++;
      SyncDispatch outcome;
      try {
        outcome = await _sender(current);
      } on Object {
        // A sender that throws instead of returning is treated as transient.
        outcome = SyncDispatch.retryable;
      }

      switch (outcome) {
        case SyncDispatch.success:
          succeeded++;
          _replace(
            id,
            current.copyWith(
              status: SyncActionStatus.done,
              attempts: current.attempts + 1,
              completedAt: _clock(),
              clearNextAttemptAt: true,
              clearLastError: true,
            ),
          );
        case SyncDispatch.retryable:
          final int nextAttempts = current.attempts + 1;
          if (nextAttempts >= maxAttempts) {
            deadLettered++;
            _replace(
              id,
              current.copyWith(
                status: SyncActionStatus.dead,
                attempts: nextAttempts,
                lastError: 'retry-exhausted',
                clearNextAttemptAt: true,
              ),
            );
          } else {
            retried++;
            _replace(
              id,
              current.copyWith(
                attempts: nextAttempts,
                nextAttemptAt: _clock().add(_backoff(nextAttempts)),
                lastError: 'retryable',
              ),
            );
          }
        case SyncDispatch.permanent:
          deadLettered++;
          _replace(
            id,
            current.copyWith(
              status: SyncActionStatus.dead,
              attempts: current.attempts + 1,
              lastError: 'permanent',
              clearNextAttemptAt: true,
            ),
          );
      }

      await _persist();
      _emit(syncing: true);
    }

    _prune();
    await _persist();
    _emit();

    return SyncFlushReport(
      dispatched: dispatched,
      succeeded: succeeded,
      retried: retried,
      deadLettered: deadLettered,
      pendingRemaining: pendingCount,
    );
  }

  /// Releases the status stream. After this the engine must not be reused.
  Future<void> dispose() async {
    final Future<void>? running = _disposing;
    if (running != null) return running;
    final Future<void> disposing = _dispose();
    _disposing = disposing;
    return disposing;
  }

  Future<void> _dispose() async {
    _disposed = true;
    final List<Future<Object?>> pending = <Future<Object?>>[_persistTail];
    final Future<void>? loading = _loadFuture;
    if (loading != null) pending.add(loading);
    final Future<SyncFlushReport>? flushing = _inFlight;
    if (flushing != null) pending.add(flushing);
    try {
      await Future.wait<Object?>(pending);
    } finally {
      await _status.close();
    }
  }

  SyncAction? _findLiveByKey(String idempotencyKey) {
    final DateTime now = _clock();
    for (final SyncAction a in _queue) {
      if (a.idempotencyKey != idempotencyKey) continue;
      if (a.isPending) return a;
      if (a.isDone) {
        final DateTime ref = a.completedAt ?? a.createdAt;
        if (now.difference(ref) < doneRetention) return a;
      }
      // Dead actions do NOT block a fresh re-enqueue: the user may retry.
    }
    return null;
  }

  int _indexOf(String id) => _queue.indexWhere((SyncAction a) => a.id == id);

  void _replace(String id, SyncAction updated) {
    final int index = _indexOf(id);
    if (index >= 0) _queue[index] = updated;
  }

  void _prune() {
    final DateTime now = _clock();
    _queue.removeWhere((SyncAction a) {
      if (a.isDone) {
        final DateTime ref = a.completedAt ?? a.createdAt;
        return now.difference(ref) >= doneRetention;
      }
      if (a.isDead) {
        return now.difference(a.createdAt) >= deadRetention;
      }
      return false;
    });
  }

  Future<void> _persist() {
    final Future<void> operation = _persistTail
        .catchError((Object _, StackTrace __) {})
        .then((_) => _store.save(List<SyncAction>.of(_queue)));
    _persistTail = operation;
    return operation;
  }

  String _nextId() {
    final String Function()? gen = _idGenerator;
    if (gen != null) return gen();
    final int micros = _clock().toUtc().microsecondsSinceEpoch;
    return 'sync_${micros}_${_idSeq++}';
  }

  void _emit({bool syncing = false}) {
    if (_status.isClosed) return;
    _status.add(
      SyncStatus(pending: pendingCount, dead: deadCount, syncing: syncing),
    );
  }

  void _ensureActive() {
    if (_disposed) throw StateError('SyncEngine has been disposed');
  }
}
