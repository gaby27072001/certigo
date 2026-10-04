import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/lesson/application/lesson_args.dart';
import 'package:certigo/features/lesson/application/lesson_controller.dart';
import 'package:certigo/features/lesson/application/lesson_feedback.dart';
import 'package:certigo/features/lesson/application/lesson_session_state.dart';
import 'package:certigo/features/lesson/application/lesson_step.dart';

/// Repositories that always fail so tests enter explicit demo mode.
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

/// A [LessonFeedback] that records *when* the controller fires haptic/sound
/// cues, so the son-&-haptique seam (§3.14) can be asserted deterministically
/// without a Flutter binding or a real device.
class _RecordingFeedback implements LessonFeedback {
  final List<bool> gradedEvents = <bool>[];
  int completedCount = 0;

  @override
  void graded({required bool correct}) => gradedEvents.add(correct);

  @override
  void completed() => completedCount++;
}

void main() {
  const LessonArgs args = LessonArgs(trackId: 'az-900', lessonId: 'sample');
  late ProviderContainer container;
  late _RecordingFeedback feedback;

  setUp(() {
    feedback = _RecordingFeedback();
    container = ProviderContainer(
      overrides: <Override>[
        lessonRepositoryProvider.overrideWithValue(_OfflineLessonRepo()),
        quizRepositoryProvider.overrideWithValue(_OfflineQuizRepo()),
        lessonFeedbackProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);
  });

  LessonController notifier() => container.read(lessonControllerProvider(args).notifier);
  LessonSessionState read() => container.read(lessonControllerProvider(args));

  /// Walks the reader to the check whose item id is [id] without grading it.
  /// Safe because no target check is the step *before* the result, so advancing
  /// here never triggers the finish-and-submit path.
  Future<void> advanceToItem(LessonController controller, String id) async {
    if (read().status == LessonStatus.error) controller.startDemo();
    var guard = 0;
    while (read().current?.item?.id != id && guard++ < 60) {
      await controller.advance();
    }
    expect(read().current?.item?.id, id, reason: 'never reached check "$id"');
  }

  group('feedback seam (§3.14 son & haptique)', () {
    test(
      'graded(correct: true) fires once when a correct check is submitted',
      () async {
        final LessonController controller = notifier();
        await controller.load();
        await advanceToItem(controller, 'chk-shared-1');

        controller.toggleOption('a'); // the correct pick
        controller.submitCheck();

        expect(feedback.gradedEvents, <bool>[true]);
        expect(feedback.completedCount, 0);
      },
    );

    test(
      'graded(correct: false) fires when a wrong check is submitted',
      () async {
        final LessonController controller = notifier();
        await controller.load();
        await advanceToItem(controller, 'chk-shared-1');

        controller.toggleOption('b'); // a wrong but submittable pick
        controller.submitCheck();

        expect(feedback.gradedEvents, <bool>[false]);
      },
    );

    test(
      'submitCheck is inert until the check is actually submittable',
      () async {
        final LessonController controller = notifier();
        await controller.load();
        await advanceToItem(controller, 'chk-order-1'); // needs all 4 slots

        controller.submitCheck(); // nothing selected → must be a no-op
        expect(feedback.gradedEvents, isEmpty);
        expect(read().currentAnswered, isFalse);
      },
    );

    test('completed() fires exactly once at the end of the lesson', () async {
      final LessonController controller = notifier();
      await controller.load();
      controller.startDemo();

      var guard = 0;
      while (read().status != LessonStatus.finished && guard++ < 60) {
        final LessonSessionState state = read();
        if (state.current?.isCheck == true && !state.currentAnswered) {
          _answerCorrectly(controller, state);
          controller.submitCheck();
        } else {
          await controller.advance();
        }
      }

      expect(read().status, LessonStatus.finished);
      expect(feedback.completedCount, 1);
      expect(
        feedback.gradedEvents.length,
        7,
        reason: 'one graded cue per check',
      );
      expect(feedback.gradedEvents.every((bool c) => c), isTrue);
    });
  });

  group('toggleMatch — both sides are single-use', () {
    test('re-pairing a left releases its previous right', () async {
      final LessonController controller = notifier();
      await controller.load();
      await advanceToItem(controller, 'chk-match-1');

      controller.toggleMatch('l1', 'r1');
      expect(read().selection, <String>['l1:r1']);

      controller.toggleMatch('l1', 'r2'); // same left, new right
      expect(read().selection, <String>['l1:r2']);
    });

    test('re-using a right reassigns it away from its previous left', () async {
      final LessonController controller = notifier();
      await controller.load();
      await advanceToItem(controller, 'chk-match-1');

      controller.toggleMatch('l1', 'r1');
      controller.toggleMatch('l2', 'r1'); // same right, new left
      expect(read().selection, <String>['l2:r1']);
    });

    test('toggling the identical pair twice removes it', () async {
      final LessonController controller = notifier();
      await controller.load();
      await advanceToItem(controller, 'chk-match-1');

      controller.toggleMatch('l1', 'r1');
      controller.toggleMatch('l1', 'r1');
      expect(read().selection, isEmpty);
    });
  });

  group('canSubmitCurrent — completeness gate per exercise type', () {
    test('ordering is submittable only when every slot is filled', () async {
      final LessonController controller = notifier();
      await controller.load();
      await advanceToItem(controller, 'chk-order-1');

      expect(read().canSubmitCurrent, isFalse);
      controller.toggleOption('s1');
      controller.toggleOption('s2');
      controller.toggleOption('s3');
      expect(read().canSubmitCurrent, isFalse, reason: '3 of 4 placed');
      controller.toggleOption('s4');
      expect(read().canSubmitCurrent, isTrue);
    });

    test('applied is submittable from two placed steps and keeps distractors out', () {
      const QuizItem item = QuizItem(
        id: 'applied-1',
        conceptId: 'concept',
        type: ItemType.applied,
        stem: 'Range les actions utiles.',
        options: <QuizOption>[
          QuizOption(id: 's1', label: 'Diagnostiquer'),
          QuizOption(id: 's2', label: 'Corriger'),
          QuizOption(id: 'd1', label: 'Ignorer l\'alerte'),
        ],
      );
      const LessonSessionState oneStep = LessonSessionState(
        lesson: Lesson(
          id: 'lesson',
          trackId: 'track',
          unitId: 'unit',
          domainId: 'domain',
          title: 'Lesson',
          estMinutes: 1,
          blocks: <LessonBlock>[],
        ),
        steps: <LessonStep>[LessonStep(kind: LessonStepKind.check, index: 0, item: item)],
        selection: <String>['s1'],
      );

      expect(oneStep.canSubmitCurrent, isFalse);
      expect(oneStep.copyWith(selection: const <String>['s1', 's2']).canSubmitCurrent, isTrue);
      expect(oneStep.copyWith(selection: const <String>['s1', 'd1']).canSubmitCurrent, isTrue);
    });

    test('cloze is submittable only when every blank is filled', () async {
      final LessonController controller = notifier();
      await controller.load();
      await advanceToItem(controller, 'chk-cloze-1'); // two blanks

      controller.toggleOption('w-iaas');
      expect(read().canSubmitCurrent, isFalse, reason: '1 of 2 blanks');
      controller.toggleOption('w-paas');
      expect(read().canSubmitCurrent, isTrue);
    });

    test('matchPairs is submittable only when every pair is made', () async {
      final LessonController controller = notifier();
      await controller.load();
      await advanceToItem(controller, 'chk-match-1'); // three lefts

      controller.toggleMatch('l1', 'r1');
      controller.toggleMatch('l2', 'r2');
      expect(read().canSubmitCurrent, isFalse, reason: '2 of 3 pairs');
      controller.toggleMatch('l3', 'r3');
      expect(read().canSubmitCurrent, isTrue);
    });

    test('mcq needs a single pick; multi needs at least one', () async {
      final LessonController controller = notifier();
      await controller.load();

      await advanceToItem(controller, 'chk-shared-1');
      expect(read().canSubmitCurrent, isFalse);
      controller.toggleOption('a');
      expect(read().canSubmitCurrent, isTrue);

      await advanceToItem(controller, 'chk-shared-2');
      expect(read().canSubmitCurrent, isFalse);
      controller.toggleOption('a');
      expect(read().canSubmitCurrent, isTrue);
    });
  });
}

/// Fills the current check's correct answer, dispatching by exercise type.
void _answerCorrectly(LessonController controller, LessonSessionState state) {
  final QuizItem item = state.current!.item!;
  switch (item.id) {
    case 'chk-shared-1':
      controller.toggleOption('a');
    case 'chk-shared-2':
      controller.toggleOption('a');
      controller.toggleOption('b');
    case 'chk-order-1':
      for (final String id in <String>['s1', 's2', 's3', 's4']) {
        controller.toggleOption(id);
      }
    case 'chk-cloze-1':
      controller.toggleOption('w-iaas');
      controller.toggleOption('w-paas');
    case 'chk-match-1':
      controller.toggleMatch('l1', 'r1');
      controller.toggleMatch('l2', 'r2');
      controller.toggleMatch('l3', 'r3');
    case 'chk-scenario-1':
      controller.toggleOption('a');
    case 'chk-spot-1':
      controller.toggleOption('a');
  }
}
