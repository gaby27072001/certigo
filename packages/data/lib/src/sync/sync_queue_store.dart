import 'dart:convert';

import 'sync_action.dart';

/// Persistence seam for the offline queue.
///
/// The engine loads the whole queue on start and writes it back after each
/// mutation. Implementations must be durable across app restarts — that is the
/// whole point of offline-first.
abstract interface class SyncQueueStore {
  Future<List<SyncAction>> load();
  Future<void> save(List<SyncAction> actions);
}

/// Volatile store — the default for tests and a safe fallback when no platform
/// storage is wired. Loses data on restart (acceptable only for tests).
class InMemorySyncQueueStore implements SyncQueueStore {
  InMemorySyncQueueStore([List<SyncAction>? seed])
    : _actions = List<SyncAction>.of(seed ?? const <SyncAction>[]);

  List<SyncAction> _actions;

  @override
  Future<List<SyncAction>> load() async => List<SyncAction>.of(_actions);

  @override
  Future<void> save(List<SyncAction> actions) async {
    _actions = List<SyncAction>.of(actions);
  }
}

/// Reads the persisted queue as a single JSON string (null if absent).
typedef JsonRead = Future<String?> Function();

/// Writes the persisted queue as a single JSON string.
typedef JsonWrite = Future<void> Function(String json);

/// Durable store that (de)serializes the queue to one JSON string via injected
/// read/write closures.
///
/// This keeps ALL queue logic inside the tested `data` package: the app only
/// supplies trivial SharedPreferences-backed closures, nothing more. It is also
/// fully unit-testable by closing over an in-memory string.
class JsonSyncQueueStore implements SyncQueueStore {
  JsonSyncQueueStore({required JsonRead read, required JsonWrite write})
    : _read = read,
      _write = write;

  final JsonRead _read;
  final JsonWrite _write;

  @override
  Future<List<SyncAction>> load() async {
    final String? raw = await _read();
    if (raw == null || raw.isEmpty) return <SyncAction>[];
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return <SyncAction>[];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> m) => SyncAction.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<void> save(List<SyncAction> actions) async {
    final String raw = jsonEncode(actions.map((SyncAction a) => a.toJson()).toList());
    await _write(raw);
  }
}
