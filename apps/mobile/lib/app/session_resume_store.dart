import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The three learning surfaces that mint a server attempt key.
///
/// Each keeps its own record, so opening a quiz does not discard a lesson left
/// in progress.
enum ResumeSurface {
  quiz('quiz'),
  lesson('lesson'),
  exam('exam');

  const ResumeSurface(this.id);

  final String id;

  String get prefsKey => 'session_resume_${id}_v1';

  static ResumeSurface? byId(String? id) {
    for (final ResumeSurface surface in ResumeSurface.values) {
      if (surface.id == id) return surface;
    }
    return null;
  }
}

/// A learning session captured so it can be resumed after the app is killed.
///
/// iOS terminates a backgrounded app without notice when it needs memory, so
/// this record is what stands between a learner and replaying a run from zero.
///
/// It carries two kinds of field, and conflating them is the whole hazard of
/// this area:
///
/// * **[progress]** — comfort. Its shape belongs to the surface that wrote it;
///   this record treats it as opaque text. Losing it costs time.
/// * **[clientAttemptId]** — correctness. It is the server's dedupe key, and
///   `SyncEngine` collapses replays *by that key alone* ("re-enqueuing the same
///   idempotencyKey … is a no-op"). The offline queue that holds a submission
///   is `SharedPreferences`-backed (`bootstrap.dart`) and already survives a
///   process death; the key that de-duplicates it did not. A resumed session
///   that minted a fresh key is therefore counted by the server as a **second
///   attempt** — `QuizService.cs:56` returns the *first* result for a known
///   key, so the two are only ever collapsed when the key is the same.
///
/// Restoring progress without restoring the key would be worse than restoring
/// nothing: it would make the double count reachable from a path that looks
/// like a feature.
///
/// The generic half is deliberately shared by the three surfaces. Writing the
/// key persistence three times would be three chances to forget it once; the
/// progress payload legitimately differs, so it stays typed at the edge where
/// each surface can validate its own shape.
///
/// ## What makes a record refusable
///
/// [ownerId] and [publicManifestId] are context, not payload. A record is
/// replayed only into the context it was written in:
///
/// * a different account must not inherit answers — the rule the active
///   certification already applies (`active_track_store.dart`);
/// * a different content manifest must not be answered with item ids captured
///   against the previous one, because those ids may now designate different
///   questions.
///
/// Under either mismatch the record is discarded rather than adapted. The
/// server stays authoritative for scoring, so dropping local progress is the
/// safe direction; guessing is not.
class SessionResumeRecord {
  const SessionResumeRecord({
    required this.surface,
    required this.ownerId,
    required this.sessionId,
    required this.publicManifestId,
    required this.clientAttemptId,
    required this.startedAt,
    required this.progress,
  });

  final ResumeSurface surface;

  /// Account this session belongs to. A record whose owner does not match the
  /// current one is discarded, never replayed.
  final String ownerId;

  /// Identifies the run within the surface — `trackId/lessonId` for a quiz or
  /// a lesson, the exam id for an exam.
  final String sessionId;

  /// Content pin the answers were captured against. `null` when the content
  /// carried none; a record only restores under the same pin.
  final String? publicManifestId;

  /// The server dedupe key for this session. Surviving the process death is
  /// the point: a resumed submission then resolves to the same server-side
  /// attempt instead of creating a second one.
  final String clientAttemptId;

  /// True session start, so a resumed submission reports when the learner
  /// actually began rather than when the app was relaunched.
  final DateTime startedAt;

  /// Surface-owned payload. Opaque here by design.
  final Map<String, dynamic> progress;

  /// Whether this record may be replayed into the given context.
  bool matches({
    required ResumeSurface surface,
    required String ownerId,
    required String sessionId,
    required String? publicManifestId,
  }) =>
      this.surface == surface &&
      this.ownerId == ownerId &&
      this.sessionId == sessionId &&
      this.publicManifestId == publicManifestId;

  SessionResumeRecord withProgress(Map<String, dynamic> progress) => SessionResumeRecord(
        surface: surface,
        ownerId: ownerId,
        sessionId: sessionId,
        publicManifestId: publicManifestId,
        clientAttemptId: clientAttemptId,
        startedAt: startedAt,
        progress: progress,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'surface': surface.id,
        'ownerId': ownerId,
        'sessionId': sessionId,
        'publicManifestId': publicManifestId,
        'clientAttemptId': clientAttemptId,
        'startedAt': startedAt.toIso8601String(),
        'progress': progress,
      };

  /// Rebuilds a record from stored text, returning `null` for anything it
  /// cannot fully account for.
  ///
  /// Every identity field is required. A record missing its owner, its session
  /// or its attempt key cannot be checked against the current context, and a
  /// record that cannot be checked must not be replayed — the safe direction
  /// is to drop local progress, never to guess at it.
  static SessionResumeRecord? fromJson(Map<String, dynamic> json) {
    final ResumeSurface? surface = ResumeSurface.byId(_text(json['surface']));
    final String? ownerId = _text(json['ownerId']);
    final String? sessionId = _text(json['sessionId']);
    final String? clientAttemptId = _text(json['clientAttemptId']);
    final DateTime? startedAt = DateTime.tryParse(_text(json['startedAt']) ?? '');
    final Object? progress = json['progress'];
    if (surface == null ||
        ownerId == null ||
        sessionId == null ||
        clientAttemptId == null ||
        startedAt == null ||
        progress is! Map) {
      return null;
    }

    return SessionResumeRecord(
      surface: surface,
      ownerId: ownerId,
      sessionId: sessionId,
      publicManifestId: _text(json['publicManifestId']),
      clientAttemptId: clientAttemptId,
      startedAt: startedAt,
      progress: Map<String, dynamic>.from(progress),
    );
  }
}

/// Atomic local record for one surface's session in progress.
abstract interface class SessionResumeStore {
  SessionResumeRecord? read(ResumeSurface surface);

  Future<void> write(SessionResumeRecord record);

  Future<void> clear(ResumeSurface surface);
}

class SharedPreferencesSessionResumeStore implements SessionResumeStore {
  const SharedPreferencesSessionResumeStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  SessionResumeRecord? read(ResumeSurface surface) =>
      _decode(_preferences.getString(surface.prefsKey));

  @override
  Future<void> write(SessionResumeRecord record) async {
    await _preferences.setString(record.surface.prefsKey, jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear(ResumeSurface surface) async {
    await _preferences.remove(surface.prefsKey);
  }
}

/// A store whose entire state is text, supplied and collected by the caller.
///
/// This is what lets a test put a real process death between two sessions: the
/// only thing that can cross is a string, so a field that is never serialised
/// cannot come back, and a store that persists nothing restores nothing.
class JsonSessionResumeStore implements SessionResumeStore {
  const JsonSessionResumeStore({required this.readJson, required this.writeJson});

  final String? Function(ResumeSurface surface) readJson;
  final Future<void> Function(ResumeSurface surface, String? json) writeJson;

  @override
  SessionResumeRecord? read(ResumeSurface surface) => _decode(readJson(surface));

  @override
  Future<void> write(SessionResumeRecord record) =>
      writeJson(record.surface, jsonEncode(record.toJson()));

  @override
  Future<void> clear(ResumeSurface surface) => writeJson(surface, null);
}

/// Default binding: remembers nothing.
///
/// Widget tests and any composition that has not opted in get this, so no test
/// silently depends on a platform channel. Production overrides it in
/// [bootstrap] with the `SharedPreferences` store.
class InMemorySessionResumeStore implements SessionResumeStore {
  final Map<ResumeSurface, SessionResumeRecord> _records = <ResumeSurface, SessionResumeRecord>{};

  @override
  SessionResumeRecord? read(ResumeSurface surface) => _records[surface];

  @override
  Future<void> write(SessionResumeRecord record) async => _records[record.surface] = record;

  @override
  Future<void> clear(ResumeSurface surface) async => _records.remove(surface);
}

SessionResumeRecord? _decode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? SessionResumeRecord.fromJson(decoded) : null;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

String? _text(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
