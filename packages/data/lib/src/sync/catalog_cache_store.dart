import 'dart:convert';

import '../models/track_summary.dart';

/// Persistence seam for the offline catalog cache.
abstract interface class CatalogCacheStore {
  /// Returns the last known catalog, or null when no cache is available.
  Future<List<TrackSummary>?> read();

  /// Replaces the cached catalog snapshot.
  Future<void> write(List<TrackSummary> tracks);
}

/// Volatile store used by tests and as a safe default before app wiring.
class InMemoryCatalogCacheStore implements CatalogCacheStore {
  InMemoryCatalogCacheStore([List<TrackSummary>? seed])
      : _tracks = seed == null ? null : List<TrackSummary>.of(seed);

  List<TrackSummary>? _tracks;

  @override
  Future<List<TrackSummary>?> read() async =>
      _tracks == null ? null : List<TrackSummary>.of(_tracks!);

  @override
  Future<void> write(List<TrackSummary> tracks) async {
    _tracks = List<TrackSummary>.of(tracks);
  }
}

/// Reads the persisted catalog cache as a single JSON string (null if absent).
typedef CatalogJsonRead = Future<String?> Function();

/// Writes the persisted catalog cache as a single JSON string.
typedef CatalogJsonWrite = Future<void> Function(String json);

/// Durable store that serializes the whole catalog as one JSON list.
class JsonCatalogCacheStore implements CatalogCacheStore {
  JsonCatalogCacheStore({
    required CatalogJsonRead read,
    required CatalogJsonWrite write,
  })  : _read = read,
        _write = write;

  final CatalogJsonRead _read;
  final CatalogJsonWrite _write;

  @override
  Future<List<TrackSummary>?> read() async {
    final String? raw = await _read();
    if (raw == null || raw.isEmpty) return null;

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return null;

    try {
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) => TrackSummary.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(List<TrackSummary> tracks) async {
    final String raw = jsonEncode(
      tracks.map((TrackSummary track) => track.toJson()).toList(),
    );
    await _write(raw);
  }
}
