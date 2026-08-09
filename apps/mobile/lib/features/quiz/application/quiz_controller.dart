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
  });

  final SubmitQuizResult result;
  final bool pendingSync;
  final int totalQuestions;
}

/// Owns the quiz game-loop state (current item, score, timing, progression) so
/// it can be driven and tested independently of the widget tree.
///
/// Questions come from the lesson API; if it is unavailable a local sample quiz
/// is used so the learning flow still works offline. Answers are submitted at
/// the end and rewards come from server grading (with a local fallback).
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
  bool _submitting = false;
  int _index = 0;
  String? _selectedId;
  bool _graded = false;
  int _correctCount = 0;
  final DateTime _startedAt = DateTime.now().toUtc();
  DateTime _shownAt = DateTime.now();
  final Map<String, List<String>> _answersByItem = <String, List<String>>{};
  final Map<String, int> _latencyByItem = <String, int>{};

  List<QuizEntry> get items => _items;
  bool get loading => _loading;
  bool get submitting => _submitting;
  int get index => _index;
  QuizEntry get current => _items[_index];
  bool get isLast => _index == _items.length - 1;
  String? get selectedId => _selectedId;
  bool get graded => _graded;
  int get correctCount => _correctCount;

  Future<void> loadItems() async {
    final Result<Lesson> lesson = await _lessons.getLesson(trackId: trackId, lessonId: lessonId);

    final List<QuizEntry> entries = lesson.when(
      success: (Lesson l) {
        final List<QuizEntry> fromApi = l.blocks
            .where((LessonBlock b) => b.check != null)
            .map((LessonBlock b) => QuizEntry(item: b.check!))
            .toList(growable: false);
        if (fromApi.isNotEmpty) return fromApi;
        return sampleQuizItems();
      },
      failure: (Failure _) => sampleQuizItems(),
    );

    _items = entries;
    _loading = false;
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

    final String clientAttemptId = DateTime.now().microsecondsSinceEpoch.toString();
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

    final Result<SubmitQuizResult> submission = await _quiz.submit(
      lessonId: lessonId,
      request: SubmitQuizRequest(
        clientAttemptId: clientAttemptId,
        trackId: trackId,
        startedAt: _startedAt,
        answers: answers,
      ),
    );

    final bool hasLocalKey = _items.any((QuizEntry entry) => entry.hasLocalCorrection);
    final bool pendingSync = submission.isFailure && !hasLocalKey;
    final SubmitQuizResult result =
        submission.valueOrNull ??
        _localFallbackResult(
          clientAttemptId: clientAttemptId,
          total: _items.length,
          hasLocalCorrection: hasLocalKey,
        );

    _submitting = false;
    notifyListeners();

    return QuizSubmission(result: result, pendingSync: pendingSync, totalQuestions: _items.length);
  }

  SubmitQuizResult _localFallbackResult({
    required String clientAttemptId,
    required int total,
    required bool hasLocalCorrection,
  }) {
    final int scorePct = hasLocalCorrection
        ? (total == 0 ? 0 : ((_correctCount / total) * 100).round())
        : 0;
    final int xp = hasLocalCorrection ? (20 + _correctCount * 10) : 0;
    return SubmitQuizResult(
      attemptId: 'local-$clientAttemptId',
      scorePct: scorePct,
      results: const <ItemResult>[],
      rewards: QuizRewards(
        xpEarned: xp,
        newXp: 1240 + xp,
        levelUp: false,
        streakExtended: false,
        gemsEarned: 0,
        achievementsUnlocked: const <String>[],
      ),
      weakConcepts: const <String>[],
    );
  }
}
