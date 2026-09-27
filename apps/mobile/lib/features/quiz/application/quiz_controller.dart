import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';

import '../../../app/session_resume_store.dart';
import 'quiz_entry.dart';
import 'quiz_resume.dart';
import 'sample_quiz.dart';
import '../../lesson/application/lesson_feedback.dart';

/// Immutable bundle carrying the outcome of a quiz submission back to the UI.
class QuizSubmission {
  const QuizSubmission({
    required this.result,
    required this.pendingSync,
    required this.totalQuestions,
    required this.isDemo,
    required this.submissionFailed,
  });

  final SubmitQuizResult result;
  final bool pendingSync;
  final int totalQuestions;
  final bool isDemo;
  final bool submissionFailed;
}

/// Owns the quiz game-loop state (current item, score, timing, progression) so
/// it can be driven and tested independently of the widget tree.
///
/// Questions come from the lesson API (including its genuine offline cache).
/// Bundled sample questions are available only after an explicit [startDemo]
/// action and are never submitted or rewarded.
class QuizController extends ChangeNotifier {
  QuizController({
    required this._lessons,
    required this._quiz,
    required this.trackId,
    required this.lessonId,
    RuntimeContentPinRegistry? contentPins,
    String? contentOwnerId,
    LessonFeedback feedback = const SilentLessonFeedback(),
    SessionResumeStore? resumeStore,
    String? resumeOwnerId,
  })  :
        // Keep the optional dependency source-compatible with direct controller tests.
        // ignore: prefer_initializing_formals
        _feedback = feedback,
        // ignore: prefer_initializing_formals
        _contentPins = contentPins,
        // ignore: prefer_initializing_formals
        _contentOwnerId = contentOwnerId,
        // Same reason as above: the store and its owner stay ordinary named
        // parameters so a controller test can inject them directly.
        // ignore: prefer_initializing_formals
        _resumeStore = resumeStore,
        // ignore: prefer_initializing_formals
        _resumeOwnerId = resumeOwnerId {
    unawaited(loadItems());
  }

  final LessonRepository _lessons;
  final QuizRepository _quiz;
  final String trackId;
  final String lessonId;
  final RuntimeContentPinRegistry? _contentPins;
  final String? _contentOwnerId;

  /// Retour audio-haptique partagé avec les leçons. Muet par défaut pour que les
  /// tests qui construisent le contrôleur directement restent déterministes.
  final LessonFeedback _feedback;

  /// Where an interrupted session is kept so it can be resumed after the app
  /// is killed. Absent in compositions that have not opted in, in which case
  /// the controller behaves exactly as before: nothing is written, nothing is
  /// restored, and the attempt key is minted on first submit.
  final SessionResumeStore? _resumeStore;
  final String? _resumeOwnerId;

  List<QuizEntry> _items = <QuizEntry>[];
  bool _loading = true;
  bool _loadFailed = false;
  bool _isDemo = false;
  bool _disposed = false;
  bool _submitting = false;
  int _index = 0;
  String? _selectedId;
  bool _graded = false;
  int _correctCount = 0;
  DateTime _startedAt = DateTime.now().toUtc();
  DateTime _shownAt = DateTime.now();
  final Map<String, List<String>> _answersByItem = <String, List<String>>{};
  final Map<String, int> _latencyByItem = <String, int>{};
  String? _publicManifestId;
  RuntimeContentPin? _contentPin;

  /// Server-dedup key for the current submission. Held for as long as the
  /// outcome is unknown — a retry after a transport failure (where the
  /// server may already have applied the attempt) has to carry the SAME key,
  /// or a duplicate attempt is created and the readiness score is inflated.
  /// Released once the server has ruled (success or permanent refusal) so a
  /// genuinely new attempt from the same controller instance is not swallowed
  /// as a replay of the previous one.
  String? _pendingAttemptId;

  List<QuizEntry> get items => _items;
  bool get loading => _loading;
  bool get loadFailed => _loadFailed;
  bool get isDemo => _isDemo;
  bool get submitting => _submitting;
  int get index => _index;
  QuizEntry get current => _items[_index];
  bool get isLast => _index == _items.length - 1;
  String? get selectedId => _selectedId;
  bool get graded => _graded;
  int get correctCount => _correctCount;

  Future<void> loadItems() async {
    _loading = true;
    _loadFailed = false;
    notifyListeners();
    final Result<Lesson> lesson = await _lessons.getLesson(trackId: trackId, lessonId: lessonId);
    if (_disposed) return;

    final List<QuizEntry> entries = lesson.when(
      success: (Lesson l) {
        _contentPin?.release();
        _contentPin = _contentPins?.pin(
          l.publicManifestId,
          ownerId: _contentOwnerId,
        );
        _publicManifestId = l.publicManifestId;
        final List<QuizEntry> fromApi = l.blocks
            .where((LessonBlock b) => b.check != null)
            .map((LessonBlock b) => QuizEntry(item: b.check!))
            .toList(growable: false);
        return fromApi;
      },
      failure: (Failure _) => const <QuizEntry>[],
    );

    _items = entries;
    _loadFailed = lesson.isFailure;
    _isDemo = false;
    if (lesson.isFailure) {
      _publicManifestId = null;
      _contentPin?.release();
      _contentPin = null;
    }
    _loading = false;
    _shownAt = DateTime.now();
    _restoreInterruptedSession();
    notifyListeners();
  }

  void startDemo() {
    if (_loading || !_loadFailed) return;
    _items = sampleQuizItems();
    _loadFailed = false;
    _isDemo = true;
    _index = 0;
    _selectedId = null;
    _graded = false;
    _correctCount = 0;
    _answersByItem.clear();
    _latencyByItem.clear();
    _publicManifestId = null;
    _contentPin?.release();
    _contentPin = null;
    _shownAt = DateTime.now();
    // Demo runs are never submitted and never rewarded, so there is nothing
    // for the server to reconcile and nothing worth outliving the process.
    _discardResume();
    notifyListeners();
  }

  void select(String optionId) {
    if (_graded) return;
    _selectedId = optionId;
    _persistResume();
    notifyListeners();
  }

  void grade() {
    if (_selectedId == null || _graded) return;
    _graded = true;
    final String pickedId = _selectedId!;
    _answersByItem[current.item.id] = <String>[pickedId];
    _latencyByItem[current.item.id] = DateTime.now().difference(_shownAt).inMilliseconds;
    if (current.hasLocalCorrection) {
      final bool ok = pickedId == current.correctOptionId;
      current.lastAnswerCorrect = ok;
      if (ok) _correctCount++;
      // Émis ici seulement : sans correction locale, `lastAnswerCorrect` reste à
      // sa valeur par défaut `false` et l'appareil annoncerait « faux » même sur
      // une bonne réponse corrigée par le serveur.
      _feedback.graded(correct: ok);
    }
    _persistResume();
    notifyListeners();
  }

  void next() {
    _index++;
    _selectedId = null;
    _graded = false;
    _shownAt = DateTime.now();
    _persistResume();
    notifyListeners();
  }

  Future<QuizSubmission?> submit() async {
    if (_submitting) return null;
    _submitting = true;
    notifyListeners();
    await Future<void>.value();
    if (_disposed) return null;

    final String clientAttemptId = _pendingAttemptId ??= _newAttemptId();
    if (_isDemo) {
      final SubmitQuizResult result = _localDemoResult(
        clientAttemptId: clientAttemptId,
        total: _items.length,
      );
      // Demo runs are locally resolved — a final outcome, so release the key.
      _pendingAttemptId = null;
      _submitting = false;
      notifyListeners();
      return QuizSubmission(
        result: result,
        pendingSync: false,
        totalQuestions: _items.length,
        isDemo: true,
        submissionFailed: false,
      );
    }

    final List<QuizAnswer> answers = _items
        .map(
          (QuizEntry entry) => QuizAnswer(
            itemId: entry.item.id,
            type: entry.item.type,
            selected: _answersByItem[entry.item.id] ?? const <String>[],
            latencyMs: _latencyByItem[entry.item.id] ?? 0,
          ),
        )
        .toList(growable: false);

    // Put the key on disk BEFORE the request leaves. If the process dies while
    // the submission is in flight, the server may already have counted this
    // attempt; the next session has to be able to present the same key rather
    // than mint a second one.
    await _writeResume();

    late final Result<SubmitQuizResult> submission;
    try {
      submission = await _quiz.submit(
        lessonId: lessonId,
        request: SubmitQuizRequest(
          clientAttemptId: clientAttemptId,
          trackId: trackId,
          startedAt: _startedAt,
          answers: answers,
          publicManifestId: _publicManifestId,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (_disposed) return null;
      // Transport failure at the client layer: the request may or may not
      // have reached the server, so we keep _pendingAttemptId — the next tap
      // has to resolve to the same server-side operation, if any.
      _submitting = false;
      notifyListeners();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'certigo.quiz',
          context: ErrorDescription('while submitting a quiz attempt'),
        ),
      );
      return QuizSubmission(
        result: _pendingResult(clientAttemptId: clientAttemptId),
        pendingSync: false,
        totalQuestions: _items.length,
        isDemo: false,
        submissionFailed: true,
      );
    }
    if (_disposed) return null;

    final Failure? failure = submission.when(
      success: (SubmitQuizResult _) => null,
      failure: (Failure failure) => failure,
    );
    final bool pendingSync = failure != null && classifyFailure(failure) == SyncDispatch.retryable;
    final bool submissionFailed = failure != null && !pendingSync;
    // Retryable failures (network/5xx/429/auth) leave the server outcome
    // unknown — hold the key so the retry dedupes. A success or a permanent
    // refusal is a final server ruling, so the key is released and a
    // deliberate next attempt gets a fresh one.
    if (!pendingSync) {
      _pendingAttemptId = null;
      // The server has ruled: this session is over and must not be replayed
      // into a second attempt. A queued one is deliberately kept — its key is
      // the only thing that will collapse the replay with whatever the learner
      // does next.
      _discardResume();
    }
    final SubmitQuizResult result =
        submission.valueOrNull ?? _pendingResult(clientAttemptId: clientAttemptId);

    _submitting = false;
    notifyListeners();

    return QuizSubmission(
      result: result,
      pendingSync: pendingSync,
      totalQuestions: _items.length,
      isDemo: false,
      submissionFailed: submissionFailed,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _contentPin?.release();
    super.dispose();
  }

  // --- interrupted-session handling -------------------------------------
  //
  // iOS kills a backgrounded app without notice, so an interrupted quiz is
  // normal, not exceptional. Two things have to outlive it: the learner's
  // progress, and the attempt key that keeps one intent from being counted
  // twice. Only the second is a correctness concern — see
  // [SessionResumeRecord].

  ResumeSurface get _surface => ResumeSurface.quiz;

  String get _sessionId => '$trackId/$lessonId';

  /// Resume is account-scoped, like the active certification. Without a known
  /// owner there is nothing to scope a record to, so nothing is written and
  /// nothing is restored.
  bool get _canResume =>
      _resumeStore != null && (_resumeOwnerId != null && _resumeOwnerId.isNotEmpty);

  /// Replays an interrupted session, if one was left in exactly this context.
  ///
  /// Called once the items are known, because a record can only be trusted
  /// against the content it was captured on: a republished lesson may reuse
  /// item ids for different questions.
  void _restoreInterruptedSession() {
    final SessionResumeStore? store = _resumeStore;
    if (!_canResume || store == null || _isDemo || _items.isEmpty) return;

    final SessionResumeRecord? record = store.read(_surface);
    if (record == null) return;
    if (!record.matches(
      surface: _surface,
      ownerId: _resumeOwnerId!,
      sessionId: _sessionId,
      publicManifestId: _publicManifestId,
    )) {
      // Another account, another lesson, or content that has been republished
      // since. Dropping is the safe direction; adapting would be a guess.
      _discardResume();
      return;
    }

    final QuizResumeProgress? progress = QuizResumeProgress.fromJson(record.progress);
    final List<String> itemIds =
        _items.map((QuizEntry entry) => entry.item.id).toList(growable: false);
    if (progress == null || !progress.fits(itemIds)) {
      _discardResume();
      return;
    }

    _index = progress.index;
    _selectedId = progress.selectedId;
    _graded = progress.graded;
    _correctCount = progress.correctCount;
    _answersByItem
      ..clear()
      ..addAll(progress.answers);
    _latencyByItem
      ..clear()
      ..addAll(progress.latencies);
    // The key the interrupted session had already claimed. Reusing it is what
    // makes a resumed submission the SAME server attempt rather than a second.
    _pendingAttemptId = record.clientAttemptId;
    _startedAt = record.startedAt;
    _shownAt = DateTime.now();
  }

  QuizResumeProgress get _progress => QuizResumeProgress(
        index: _index,
        selectedId: _selectedId,
        graded: _graded,
        correctCount: _correctCount,
        answers: _answersByItem,
        latencies: _latencyByItem,
      );

  /// Persists the session without blocking the interaction that triggered it.
  void _persistResume() => unawaited(_writeResume());

  Future<void> _writeResume() async {
    final SessionResumeStore? store = _resumeStore;
    if (!_canResume || store == null || _isDemo || _items.isEmpty) return;
    final QuizResumeProgress progress = _progress;
    if (!progress.isWorthResuming) return;

    await store.write(
      SessionResumeRecord(
        surface: _surface,
        ownerId: _resumeOwnerId!,
        sessionId: _sessionId,
        publicManifestId: _publicManifestId,
        // Minted here when the learner first makes progress rather than at
        // submit time, so the key exists on disk before anything can claim it
        // server-side.
        clientAttemptId: _pendingAttemptId ??= _newAttemptId(),
        startedAt: _startedAt,
        progress: progress.toJson(),
      ),
    );
  }

  void _discardResume() {
    final SessionResumeStore? store = _resumeStore;
    if (store == null) return;
    unawaited(store.clear(_surface));
  }

  SubmitQuizResult _localDemoResult({required String clientAttemptId, required int total}) {
    final int scorePct = total == 0 ? 0 : ((_correctCount / total) * 100).round();
    return SubmitQuizResult(
      attemptId: 'demo-$clientAttemptId',
      scorePct: scorePct,
      results: const <ItemResult>[],
      rewards: const QuizRewards(
        xpEarned: 0,
        newXp: 0,
        levelUp: false,
        streakExtended: false,
        gemsEarned: 0,
        achievementsUnlocked: <String>[],
      ),
      weakConcepts: const <String>[],
    );
  }

  static String _newAttemptId() {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    final int rand = Random.secure().nextInt(0x7fffffff);
    return '${micros.toRadixString(16)}-${rand.toRadixString(16)}';
  }

  SubmitQuizResult _pendingResult({required String clientAttemptId}) {
    return SubmitQuizResult(
      attemptId: 'pending-$clientAttemptId',
      scorePct: 0,
      results: const <ItemResult>[],
      rewards: const QuizRewards(
        xpEarned: 0,
        newXp: 0,
        levelUp: false,
        streakExtended: false,
        gemsEarned: 0,
        achievementsUnlocked: <String>[],
      ),
      weakConcepts: const <String>[],
    );
  }
}
