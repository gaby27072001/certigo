import 'dart:convert';

import 'package:crypto/crypto.dart';

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

typedef SyncQueueQuarantineWriter = Future<bool> Function(SyncQueueCorruption corruption);

typedef SyncQueueCorruptionReporter = void Function(
  SyncQueueCorruption corruption, {
  required bool persisted,
});

abstract interface class OwnerScopedSyncQueueStore {
  void discardRetainedOwner(String ownerId);
}

class _RetainedQueueEntry {
  const _RetainedQueueEntry(this.raw, this.ownerId);

  final String raw;
  final String? ownerId;
}

class SyncQueueCorruption {
  const SyncQueueCorruption({
    required this.fingerprint,
    required this.reason,
    required this.raw,
    this.index,
    this.ownerId,
  });

  final String fingerprint;
  final String reason;
  final String raw;
  final int? index;
  final String? ownerId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': 'certigo.sync.queue-quarantine/v1',
        'fingerprint': fingerprint,
        'reason': reason,
        if (index != null) 'index': index,
        if (ownerId != null) 'ownerId': ownerId,
        'raw': raw,
      };
}

/// Durable store that (de)serializes the queue to one JSON string via injected
/// read/write closures.
///
/// This keeps ALL queue logic inside the tested `data` package: the app only
/// supplies trivial SharedPreferences-backed closures, nothing more. It is also
/// fully unit-testable by closing over an in-memory string.
class JsonSyncQueueStore implements SyncQueueStore, OwnerScopedSyncQueueStore {
  static const String _retainedRootKey = '__certigoRetainedCorruptQueueRoot';

  JsonSyncQueueStore({
    required JsonRead read,
    required JsonWrite write,
    SyncQueueQuarantineWriter? quarantine,
    SyncQueueCorruptionReporter? onCorruption,
  })  : _read = read,
        _write = write,
        _quarantine = quarantine,
        _onCorruption = onCorruption;

  final JsonRead _read;
  final JsonWrite _write;
  final SyncQueueQuarantineWriter? _quarantine;
  final SyncQueueCorruptionReporter? _onCorruption;
  final List<_RetainedQueueEntry> _unpersistedEntries = <_RetainedQueueEntry>[];
  String? _unpersistedRoot;

  @override
  Future<List<SyncAction>> load() async {
    final String? raw = await _read();
    if (raw == null || raw.isEmpty) return <SyncAction>[];
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      final bool persisted = await _recordCorruption(raw: raw, reason: 'invalid-json');
      if (!persisted) _unpersistedRoot = raw;
      return <SyncAction>[];
    }
    if (decoded is! List<dynamic>) {
      final bool persisted = await _recordCorruption(raw: raw, reason: 'root-not-list');
      if (!persisted) _unpersistedRoot = raw;
      return <SyncAction>[];
    }

    final List<SyncAction> actions = <SyncAction>[];
    for (var index = 0; index < decoded.length; index++) {
      final dynamic value = decoded[index];
      if (value is! Map<dynamic, dynamic>) {
        final String entryRaw = jsonEncode(value);
        final bool persisted = await _recordCorruption(
          raw: entryRaw,
          reason: 'entry-not-object',
          index: index,
        );
        if (!persisted) _unpersistedEntries.add(_RetainedQueueEntry(entryRaw, null));
        continue;
      }
      final dynamic retainedRoot = value[_retainedRootKey];
      if (retainedRoot is String) {
        final bool persisted = await _recordCorruption(
          raw: retainedRoot,
          reason: 'invalid-json',
          index: index,
        );
        if (!persisted) _unpersistedRoot = retainedRoot;
        continue;
      }
      try {
        actions.add(SyncAction.fromJson(Map<String, dynamic>.from(value)));
      } on FormatException {
        final String entryRaw = jsonEncode(value);
        final bool persisted = await _recordCorruption(
          raw: entryRaw,
          reason: 'entry-format',
          index: index,
          ownerId: _ownerId(value),
        );
        if (!persisted) {
          _unpersistedEntries.add(_RetainedQueueEntry(entryRaw, _ownerId(value)));
        }
      } on TypeError {
        final String entryRaw = jsonEncode(value);
        final bool persisted = await _recordCorruption(
          raw: entryRaw,
          reason: 'entry-type',
          index: index,
          ownerId: _ownerId(value),
        );
        if (!persisted) {
          _unpersistedEntries.add(_RetainedQueueEntry(entryRaw, _ownerId(value)));
        }
      } on ArgumentError {
        final String entryRaw = jsonEncode(value);
        final bool persisted = await _recordCorruption(
          raw: entryRaw,
          reason: 'entry-argument',
          index: index,
          ownerId: _ownerId(value),
        );
        if (!persisted) {
          _unpersistedEntries.add(_RetainedQueueEntry(entryRaw, _ownerId(value)));
        }
      }
    }
    return actions;
  }

  @override
  Future<void> save(List<SyncAction> actions) async {
    final List<dynamic> values = <dynamic>[
      ...actions.map((SyncAction action) => action.toJson()),
      ..._unpersistedEntries.map<dynamic>((_RetainedQueueEntry entry) => jsonDecode(entry.raw)),
      if (_unpersistedRoot != null) <String, dynamic>{_retainedRootKey: _unpersistedRoot},
    ];
    final String raw = jsonEncode(values);
    await _write(raw);
  }

  @override
  void discardRetainedOwner(String ownerId) {
    final String normalized = ownerId.trim();
    _unpersistedEntries.removeWhere(
      (_RetainedQueueEntry entry) => entry.ownerId == normalized,
    );
  }

  Future<bool> _recordCorruption({
    required String raw,
    required String reason,
    int? index,
    String? ownerId,
  }) async {
    final String fingerprint =
        sha256.convert(utf8.encode('$reason|${index ?? -1}|$raw')).toString();
    final SyncQueueCorruption corruption = SyncQueueCorruption(
      fingerprint: fingerprint,
      reason: reason,
      raw: raw,
      index: index,
      ownerId: ownerId,
    );
    final SyncQueueQuarantineWriter? quarantine = _quarantine;
    final bool persisted = quarantine != null && await quarantine(corruption);
    _onCorruption?.call(corruption, persisted: persisted);
    return persisted;
  }

  static String? _ownerId(Map<dynamic, dynamic> value) {
    final dynamic ownerId = value['ownerId'];
    if (ownerId is! String) return null;
    final String normalized = ownerId.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
