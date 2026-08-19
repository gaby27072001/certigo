import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String kActiveTrackPrefsKey = 'active_track_v2';

class ActiveTrackRecord {
  const ActiveTrackRecord({
    required this.trackId,
    required this.ownerId,
    this.pendingMutationId,
    this.pendingBaseTrackId,
    this.pendingPredecessors = const <String>[],
  });

  factory ActiveTrackRecord.synced({
    required String trackId,
    required String ownerId,
  }) =>
      ActiveTrackRecord(trackId: trackId, ownerId: ownerId);

  factory ActiveTrackRecord.pending({
    required String trackId,
    required String ownerId,
    required String mutationId,
    required String? baseTrackId,
    List<String> predecessors = const <String>[],
  }) =>
      ActiveTrackRecord(
        trackId: trackId,
        ownerId: ownerId,
        pendingMutationId: mutationId,
        pendingBaseTrackId: baseTrackId,
        pendingPredecessors: predecessors,
      );

  final String trackId;
  final String ownerId;
  final String? pendingMutationId;
  final String? pendingBaseTrackId;
  final List<String> pendingPredecessors;

  bool get isPending => pendingMutationId != null;

  ActiveTrackRecord asSynced() => ActiveTrackRecord.synced(trackId: trackId, ownerId: ownerId);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'trackId': trackId,
        'ownerId': ownerId,
        if (pendingMutationId != null) ...<String, dynamic>{
          'pendingMutationId': pendingMutationId,
          'pendingBaseTrackId': pendingBaseTrackId,
          'pendingPredecessors': pendingPredecessors,
        },
      };

  static ActiveTrackRecord? fromJson(Map<String, dynamic> json) {
    final String? trackId = _normalize(json['trackId'] as String?);
    final String? ownerId = _normalizeOwner(json['ownerId'] as String?);
    if (trackId == null || ownerId == null) return null;
    final String? mutationId = _normalizeOwner(json['pendingMutationId'] as String?);
    final List<String> predecessors = (json['pendingPredecessors'] as List<dynamic>? ?? <dynamic>[])
        .whereType<String>()
        .map(_normalize)
        .whereType<String>()
        .toList(growable: false);
    return ActiveTrackRecord(
      trackId: trackId,
      ownerId: ownerId,
      pendingMutationId: mutationId,
      pendingBaseTrackId:
          mutationId == null ? null : _normalize(json['pendingBaseTrackId'] as String?),
      pendingPredecessors: mutationId == null ? const <String>[] : predecessors,
    );
  }
}

/// Atomic local record for the selected certification and any unsynced change.
abstract interface class ActiveTrackStore {
  ActiveTrackRecord? read();

  Future<void> write(ActiveTrackRecord record);

  Future<void> clear();
}

class SharedPreferencesActiveTrackStore implements ActiveTrackStore {
  const SharedPreferencesActiveTrackStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  ActiveTrackRecord? read() {
    final String? raw = _preferences.getString(kActiveTrackPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? ActiveTrackRecord.fromJson(decoded) : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(ActiveTrackRecord record) async {
    final bool saved = await _preferences.setString(
      kActiveTrackPrefsKey,
      jsonEncode(record.toJson()),
    );
    if (!saved) {
      throw StateError('Unable to persist the active certification.');
    }
  }

  @override
  Future<void> clear() async {
    final bool existed = _preferences.containsKey(kActiveTrackPrefsKey);
    final bool removed = await _preferences.remove(kActiveTrackPrefsKey);
    if (existed && !removed) {
      throw StateError('Unable to clear the active certification.');
    }
  }
}

class InMemoryActiveTrackStore implements ActiveTrackStore {
  InMemoryActiveTrackStore([ActiveTrackRecord? seed]) : _record = seed;

  InMemoryActiveTrackStore.synced(String trackId, {String ownerId = 'user-1'})
      : _record = ActiveTrackRecord.synced(trackId: trackId, ownerId: ownerId);

  ActiveTrackRecord? _record;

  @override
  ActiveTrackRecord? read() => _record;

  @override
  Future<void> write(ActiveTrackRecord record) async {
    _record = record;
  }

  @override
  Future<void> clear() async {
    _record = null;
  }
}

String? _normalize(String? value) {
  final String normalized = (value ?? '').trim().toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

String? _normalizeOwner(String? value) {
  final String normalized = (value ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}
