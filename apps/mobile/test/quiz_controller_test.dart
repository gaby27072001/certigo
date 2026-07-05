import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/quiz/application/quiz_controller.dart';

/// Repositories that always fail, forcing the controller's offline path so the
/// game-loop can be exercised deterministically without a network or a widget.
class _OfflineLessonRepo implements LessonRepository {
  @override
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  }) async =>
      const Err<Lesson>(NetworkFailure());
}

class _OfflineQuizRepo implements QuizRepository {
  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) async =>
      const Err<SubmitQuizResult>(NetworkFailure());
}

void main() {
  /// Builds a controller on the offline fallback and drains the microtask queue
  /// so the constructor's `loadItems()` has completed before assertions run.
  Future<QuizController> loadedController() async {
    final QuizController controller = QuizController(
      lessons: _OfflineLessonRepo(),
      quiz: _OfflineQuizRepo(),
      trackId: 'az-900',
      lessonId: 'sample',
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    return controller;
  }

  group('QuizController — offline load', () {
    test('falls back to the bundled sample quiz when the API fails', () async {
      final QuizController controller = await loadedController();

      expect(controller.loading, isFalse);
      expect(controller.items.length, 3);
      expect(controller.index, 0);
      expect(controller.current.item.id, 'q-capex-1');
      expect(controller.graded, isFalse);
      expect(controller.selectedId, isNull);
    });
  });

  group('QuizController — select / grade scoring', () {
    test('a correct pick is graded, scored and notifies listeners', () async {
      final QuizController controller = await loadedController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.select('b'); // q-capex-1 → correct answer is 'b'
      expect(controller.selectedId, 'b');

      controller.grade();
      expect(controller.graded, isTrue);
      expect(controller.correctCount, 1);
      expect(controller.current.lastAnswerCorrect, isTrue);
      expect(notifications, 2, reason: 'one notify for select, one for grade');
    });

    test('a wrong pick is graded but does not score', () async {
      final QuizController controller = await loadedController();

      controller.select('a'); // wrong for q-capex-1
      controller.grade();

      expect(controller.graded, isTrue);
      expect(controller.correctCount, 0);
      expect(controller.current.lastAnswerCorrect, isFalse);
    });

    test('select is inert once the item has been graded', () async {
      final QuizController controller = await loadedController();

      controller.select('b');
      controller.grade();
      controller.select('a'); // must be ignored after grading

      expect(controller.selectedId, 'b');
    });

    test('grade is a no-op when nothing is selected', () async {
      final QuizController controller = await loadedController();

      controller.grade();

      expect(controller.graded, isFalse);
      expect(controller.correctCount, 0);
    });
  });

  group('QuizController — progression', () {
    test('next advances the index and resets per-question state', () async {
      final QuizController controller = await loadedController();

      controller.select('b');
      controller.grade();
      controller.next();

      expect(controller.index, 1);
      expect(controller.selectedId, isNull);
      expect(controller.graded, isFalse);
      expect(controller.current.item.id, 'q-capex-2');
      expect(controller.isLast, isFalse);
    });

    test('isLast is true on the final item', () async {
      final QuizController controller = await loadedController();

      controller.next();
      controller.next();

      expect(controller.index, 2);
      expect(controller.isLast, isTrue);
      expect(controller.current.item.id, 'q-capex-3');
    });
  });

  group('QuizController — submit', () {
    test('a full correct run returns a locally-graded QuizSubmission', () async {
      final QuizController controller = await loadedController();

      // Answer all three correctly: q-capex-1 → b, q-capex-2 → c, q-capex-3 → a.
      controller.select('b');
      controller.grade();
      controller.next();
      controller.select('c');
      controller.grade();
      controller.next();
      controller.select('a');
      controller.grade();

      expect(controller.isLast, isTrue);
      expect(controller.correctCount, 3);

      final QuizSubmission? submission = await controller.submit();

      expect(submission, isNotNull);
      expect(submission!.totalQuestions, 3);
      // A local answer-key exists, so the offline failure is not a pending sync.
      expect(submission.pendingSync, isFalse);
      expect(submission.result.scorePct, 100);
      expect(submission.result.rewards.xpEarned, 50); // 20 + 3 * 10
      expect(controller.submitting, isFalse);
    });

    test('submit is re-entrancy guarded while a submission is in flight', () async {
      final QuizController controller = await loadedController();

      final Future<QuizSubmission?> first = controller.submit();
      final QuizSubmission? second = await controller.submit();
      await first;

      expect(second, isNull, reason: 'a second concurrent submit is ignored');
    });
  });
}
