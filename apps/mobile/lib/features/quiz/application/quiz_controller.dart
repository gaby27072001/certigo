import 'dart:async';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';

import 'quiz_entry.dart';
import 'sample_quiz.dart';

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
  }) {
    unawaited(loadItems());
  }

  final LessonRepository _lessons;
  final QuizRepository _quiz;
  final String trackId;
  final String lessonId;

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
  final DateTime _startedAt = DateTime.now().toUtc();
  DateTime _shownAt = DateTime.now();
  final Map<String, List<String>> _answersByItem = <String, List<String>>{};
  final Map<String, int> _latencyByItem = <String, int>{};
  String? _publicManifestId;

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
    if (lesson.isFailure) _publicManifestId = null;
    _loading = false;
    _shownAt = DateTime.now();
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
    _shownAt = DateTime.now();
    notifyListeners();
  }

  void select(String optionId) {
    if (_graded) return;
    _selectedId = optionId;
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
    }
    notifyListeners();
  }

  void next() {
    _index++;
    _selectedId = null;
    _graded = false;
    _shownAt = DateTime.now();
    notifyListeners();
  }

  Future<QuizSubmission?> submit() async {
    if (_submitting) return null;
    _submitting = true;
    notifyListeners();
    await Future<void>.value();
    if (_disposed) return null;

    final String clientAttemptId = DateTime.now().microsecondsSinceEpoch.toString();
    if (_isDemo) {
      final SubmitQuizResult result = _localDemoResult(
        clientAttemptId: clientAttemptId,
        total: _items.length,
      );
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
    super.dispose();
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
