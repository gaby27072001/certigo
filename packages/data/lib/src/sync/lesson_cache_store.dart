import 'dart:convert';

import '../models/lesson.dart';

/// Persistence seam for the offline lesson cache.
///
/// The cache is *version-aware*: every entry is scoped to a content manifest
/// version. Reading with a different version than the one stored is treated as
/// a miss (the cached content is considered stale), and the next write purges
/// every entry from any previous version. This is how wp-p1-08 satisfies its
/// cache-invalidation requirement without the client yet carrying a per-lesson
/// version field — the manifest version is the single invalidation key.
abstract interface class LessonCacheStore {
  /// Returns the cached lesson for [trackId]/[lessonId] when it was stored under
  /// [manifestVersion], or null on a miss (absent, or stored under an older
  /// manifest version and therefore invalidated).
  Future<Lesson?> read({
    required String manifestVersion,
    required String trackId,
    required String lessonId,
  });

  /// Persists [lesson] under [manifestVersion]. Writing a version different from
  /// the one currently stored purges every previously cached lesson first, so
  /// stale content never survives a manifest bump.
  Future<void> write({required String manifestVersion, required Lesson lesson});
}

String _lessonKey(String trackId, String lessonId) => '$trackId/$lessonId';

/// Volatile store used by tests and as a safe default before app wiring.
class InMemoryLessonCacheStore implements LessonCacheStore {
  InMemoryLessonCacheStore();

  String? _version;
  final Map<String, Lesson> _lessons = <String, Lesson>{};

  @override
  Future<Lesson?> read({
    required String manifestVersion,
    required String trackId,
    required String lessonId,
  }) async {
    if (_version != manifestVersion) return null;
    return _lessons[_lessonKey(trackId, lessonId)];
  }

  @override
  Future<void> write({required String manifestVersion, required Lesson lesson}) async {
    if (_version != manifestVersion) {
      _version = manifestVersion;
      _lessons.clear();
    }
    _lessons[_lessonKey(lesson.trackId, lesson.id)] = lesson;
  }
}

/// Reads the persisted lesson cache as a single JSON string (null if absent).
typedef LessonJsonRead = Future<String?> Function();

/// Writes the persisted lesson cache as a single JSON string.
typedef LessonJsonWrite = Future<void> Function(String json);

/// Durable store that serialises the whole lesson cache as one JSON document:
/// `{"manifestVersion": "<v>", "lessons": {"<track>/<lesson>": {..lesson..}}}`.
class JsonLessonCacheStore implements LessonCacheStore {
  JsonLessonCacheStore({required LessonJsonRead read, required LessonJsonWrite write})
    : _read = read,
      _write = write;

  final LessonJsonRead _read;
  final LessonJsonWrite _write;

  Future<Map<String, dynamic>?> _decodeDocument() async {
    final String? raw = await _read();
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Lesson?> read({
    required String manifestVersion,
    required String trackId,
    required String lessonId,
  }) async {
    final Map<String, dynamic>? doc = await _decodeDocument();
    if (doc == null) return null;
    if (doc['manifestVersion'] != manifestVersion) return null;

    final dynamic lessons = doc['lessons'];
    if (lessons is! Map) return null;

    final dynamic entry = lessons[_lessonKey(trackId, lessonId)];
    if (entry is! Map) return null;

    try {
      return Lesson.fromJson(Map<String, dynamic>.from(entry));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({required String manifestVersion, required Lesson lesson}) async {
    final Map<String, dynamic>? doc = await _decodeDocument();

    // Keep existing entries only when the manifest version matches; otherwise
    // start fresh so content from a previous manifest version is purged.
    final Map<String, dynamic> lessons =
        (doc != null && doc['manifestVersion'] == manifestVersion && doc['lessons'] is Map)
        ? Map<String, dynamic>.from(doc['lessons'] as Map)
        : <String, dynamic>{};

    lessons[_lessonKey(lesson.trackId, lesson.id)] = lesson.toJson();

    final String raw = jsonEncode(<String, dynamic>{
      'manifestVersion': manifestVersion,
      'lessons': lessons,
    });
    await _write(raw);
  }
}
