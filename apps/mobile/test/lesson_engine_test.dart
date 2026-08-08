import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/lesson/application/check_outcome.dart';
import 'package:certigo/features/lesson/application/lesson_args.dart';
import 'package:certigo/features/lesson/application/lesson_controller.dart';
import 'package:certigo/features/lesson/application/lesson_feedback.dart';
import 'package:certigo/features/lesson/application/lesson_session_state.dart';
import 'package:certigo/features/lesson/application/lesson_step.dart';
import 'package:certigo/features/lesson/application/sample_lesson.dart';

/// Repositories that always fail, forcing the controller's offline path
/// (bundled sample lesson + embedded answer key + locally computed result).
class _OfflineLessonRepo implements LessonRepository {
  @override
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  }) async => const Err<Lesson>(NetworkFailure());
}

class _OfflineQuizRepo implements QuizRepository {
  int calls = 0;

  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) async {
    calls++;
    return const Err<SubmitQuizResult>(NetworkFailure());
  }
}

/// Answers the current check **correctly**, dispatching by exercise type:
/// `matchPairs` is driven by `toggleMatch(left, right)`; every other type fills
/// its slots via `toggleOption` in the key's (ordered) sequence.
void _answerCorrectly(
  LessonController controller,
  LessonSessionState state,
  Map<String, CheckOutcome> key,
) {
  final QuizItem item = state.current!.item!;
  final List<String> correct = key[item.id]!.correctAnswer;
  if (item.type == ItemType.matchPairs) {
    for (final String token in correct) {
      final List<String> parts = token.split(':');
      controller.toggleMatch(parts[0], parts[1]);
    }
  } else {
    for (final String id in correct) {
      controller.toggleOption(id);
    }
  }
}

/// Answers the current check **wrong but submittable** — every required slot is
/// filled so `canSubmitCurrent` is satisfied, yet the answer still grades as
/// incorrect. This exercises the failure path for *every* exercise type.
void _answerWrong(
  LessonController controller,
  LessonSessionState state,
  Map<String, CheckOutcome> key,
) {
  final QuizItem item = state.current!.item!;
  final List<String> correct = key[item.id]!.correctAnswer;
  switch (item.type) {
    case ItemType.ordering:
    case ItemType.cloze:
    case ItemType.applied:
      // Right ids, wrong order — order-sensitive grading marks it incorrect.
      for (final String id in correct.reversed) {
        controller.toggleOption(id);
      }
    case ItemType.matchPairs:
      // A full but mis-matched set: each left paired with the *next* right.
      final List<QuizOption> lefts = item.options;
      final List<QuizOption> rights = item.matches;
      for (int i = 0; i < lefts.length; i++) {
        controller.toggleMatch(lefts[i].id, rights[(i + 1) % rights.length].id);
      }
    case ItemType.mcq:
    case ItemType.multi:
    case ItemType.scenario:
    case ItemType.spotTheIssue:
    case ItemType.unknown:
      // A single option that is not part of the correct answer.
      final QuizOption wrong = item.options.firstWhere(
        (QuizOption o) => !correct.contains(o.id),
        orElse: () => item.options.first,
      );
      controller.toggleOption(wrong.id);
  }
}

void main() {
  group('buildLessonSteps', () {
    test('flattens intro + blocks + result, checks carry their items', () {
      final Lesson lesson = sampleLesson('l1');
      final List<LessonStep> steps = buildLessonSteps(lesson);

      expect(steps.first.kind, LessonStepKind.intro);
      expect(steps.last.kind, LessonStepKind.result);
      expect(steps.length, lesson.blocks.length + 2);

      final List<LessonStep> checks = steps
          .where((LessonStep s) => s.isCheck)
          .toList();
      expect(checks.length, 7);
      expect(checks.every((LessonStep s) => s.item != null), isTrue);
      expect(
        checks.map((LessonStep s) => s.item!.id),
        containsAll(<String>[
          'chk-shared-1',
          'chk-shared-2',
          'chk-order-1',
          'chk-cloze-1',
          'chk-match-1',
          'chk-scenario-1',
          'chk-spot-1',
        ]),
      );

      for (int i = 0; i < steps.length; i++) {
        expect(steps[i].index, i);
      }
    });
  });

  group('EmbeddedKeyGrader', () {
    final EmbeddedKeyGrader grader = EmbeddedKeyGrader(sampleAnswerKey());

    test('marks the exact single answer correct', () {
      final CheckOutcome o = grader.grade(
        itemId: 'chk-shared-1',
        selected: <String>['a'],
      );
      expect(o.correct, isTrue);
      expect(o.correctAnswer, <String>['a']);
      expect(o.explanation, isNotEmpty);
    });

    test('marks a wrong single answer incorrect', () {
      final CheckOutcome o = grader.grade(
        itemId: 'chk-shared-1',
        selected: <String>['b'],
      );
      expect(o.correct, isFalse);
    });

    test('multi-select is order-independent', () {
      final CheckOutcome o = grader.grade(
        itemId: 'chk-shared-2',
        selected: <String>['b', 'a'],
      );
      expect(o.correct, isTrue);
    });

    test('a partial multi-select answer is incorrect', () {
      final CheckOutcome o = grader.grade(
        itemId: 'chk-shared-2',
        selected: <String>['a'],
      );
      expect(o.correct, isFalse);
    });

    test('an unknown item yields the empty outcome', () {
      final CheckOutcome o = grader.grade(
        itemId: 'nope',
        selected: <String>['a'],
      );
      expect(o.correct, isFalse);
      expect(o.correctAnswer, isEmpty);
    });
  });

  group('LessonController (offline path)', () {
    const LessonArgs args = LessonArgs(trackId: 'az-900', lessonId: 'sample');
    late ProviderContainer container;
    late _OfflineQuizRepo quiz;

    setUp(() {
      quiz = _OfflineQuizRepo();
      container = ProviderContainer(
        overrides: <Override>[
          lessonRepositoryProvider.overrideWithValue(_OfflineLessonRepo()),
          quizRepositoryProvider.overrideWithValue(quiz),
          lessonFeedbackProvider.overrideWithValue(
            const SilentLessonFeedback(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    LessonController notifier() =>
        container.read(lessonControllerProvider(args).notifier);
    LessonSessionState read() => container.read(lessonControllerProvider(args));

    test(
      'keeps a repository failure explicit until demo is requested',
      () async {
        final LessonController controller = notifier();
        await controller.load();

        final LessonSessionState state = read();
        expect(state.status, LessonStatus.error);
        expect(state.lesson, isNull);
        expect(state.isDemo, isFalse);
      },
    );

    test('starts bundled content only through explicit demo mode', () async {
      final LessonController controller = notifier();
      await controller.load();
      controller.startDemo();

      final LessonSessionState state = read();
      expect(state.status, LessonStatus.ready);
      expect(state.lesson, isNotNull);
      expect(state.lesson!.id, 'certigo-demo');
      expect(state.isDemo, isTrue);
      expect(state.steps.first.kind, LessonStepKind.intro);
      expect(state.checksTotal, 7);
    });

    test('grades a check inline and reveals the outcome', () async {
      final LessonController controller = notifier();
      await controller.load();
      controller.startDemo();

      while (!(read().current?.isCheck ?? false)) {
        await controller.advance();
      }
      controller.toggleOption('a');
      controller.submitCheck();

      final LessonSessionState state = read();
      expect(state.status, LessonStatus.graded);
      expect(state.currentAnswered, isTrue);
      expect(state.currentOutcome?.correct, isTrue);
    });

    test('completes demo locally without submission or rewards', () async {
      final LessonController controller = notifier();
      await controller.load();
      controller.startDemo();
      final Map<String, CheckOutcome> key = sampleAnswerKey();

      var guard = 0;
      while (read().status != LessonStatus.finished && guard++ < 50) {
        final LessonSessionState state = read();
        final LessonStep? step = state.current;
        if (step != null && step.isCheck && !state.currentAnswered) {
          _answerCorrectly(controller, state, key);
          controller.submitCheck();
        } else {
          await controller.advance();
        }
      }

      final LessonSessionState state = read();
      expect(state.status, LessonStatus.finished);
      expect(state.result, isNotNull);
      expect(state.result!.scorePct, 100);
      expect(state.result!.weakConcepts, isEmpty);
      expect(state.result!.results.length, 7);
      expect(state.result!.rewards.xpEarned, 0);
      expect(state.result!.rewards.newXp, 0);
      expect(state.pendingSync, isFalse);
      expect(quiz.calls, 0);
    });

    test('a wrong answer surfaces the concept as weak in the result', () async {
      final LessonController controller = notifier();
      await controller.load();
      controller.startDemo();
      final Map<String, CheckOutcome> key = sampleAnswerKey();

      var guard = 0;
      while (read().status != LessonStatus.finished && guard++ < 50) {
        final LessonSessionState state = read();
        final LessonStep? step = state.current;
        if (step != null && step.isCheck && !state.currentAnswered) {
          // Wrong but submittable for every exercise type.
          _answerWrong(controller, state, key);
          controller.submitCheck();
        } else {
          await controller.advance();
        }
      }

      final LessonSessionState state = read();
      expect(state.status, LessonStatus.finished);
      expect(state.result!.weakConcepts, isNotEmpty);
      expect(state.result!.scorePct, lessThan(100));
    });
  });
}
