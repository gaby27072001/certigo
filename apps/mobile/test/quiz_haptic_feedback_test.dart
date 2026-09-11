import 'package:certigo/features/lesson/application/lesson_feedback.dart';
import 'package:certigo/features/quiz/application/quiz_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde de **comportement natif** : le retour haptique du quiz.
///
/// Le retour haptique est l'un des marqueurs « natif » les plus forts et les
/// moins coûteux. Les leçons en émettaient depuis toujours
/// (`HapticLessonFeedback` : moyen si juste, fort si faux), mais le quiz — l'autre
/// moitié de la boucle d'apprentissage — restait muet : valider une bonne et une
/// mauvaise réponse se ressentait pareil dans la main.
///
/// Ces tests fixent le contrat, y compris le cas subtil qui compte le plus : ne
/// **rien** émettre quand la correction n'est pas connue localement.
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

/// Enregistre *quand* et *avec quoi* le contrôleur déclenche le retour, plutôt
/// que de tenter d'observer une vraie vibration (impossible hors appareil).
class _RecordingFeedback implements LessonFeedback {
  final List<bool> gradedCalls = <bool>[];
  int completedCount = 0;

  @override
  void graded({required bool correct}) => gradedCalls.add(correct);

  @override
  void completed() => completedCount++;
}

void main() {
  Future<QuizController> loadedController(LessonFeedback feedback) async {
    final QuizController controller = QuizController(
      lessons: _OfflineLessonRepo(),
      quiz: _OfflineQuizRepo(),
      trackId: 'az-900',
      lessonId: 'sample',
      feedback: feedback,
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    controller.startDemo();
    return controller;
  }

  group('retour haptique du quiz', () {
    test('une bonne réponse déclenche un retour « correct »', () async {
      final _RecordingFeedback feedback = _RecordingFeedback();
      final QuizController controller = await loadedController(feedback);

      controller.select(controller.current.correctOptionId!);
      controller.grade();

      expect(feedback.gradedCalls, <bool>[true]);
    });

    test('une mauvaise réponse déclenche un retour « incorrect »', () async {
      final _RecordingFeedback feedback = _RecordingFeedback();
      final QuizController controller = await loadedController(feedback);

      final String wrong = controller.current.item.options
          .map((QuizOption o) => o.id)
          .firstWhere((String id) => id != controller.current.correctOptionId);
      controller.select(wrong);
      controller.grade();

      expect(feedback.gradedCalls, <bool>[false]);
    });

    test('corriger deux fois la même question n\'émet qu\'un seul retour', () async {
      final _RecordingFeedback feedback = _RecordingFeedback();
      final QuizController controller = await loadedController(feedback);

      controller.select(controller.current.correctOptionId!);
      controller.grade();
      controller.grade();

      expect(
        feedback.gradedCalls,
        hasLength(1),
        reason: 'Un retour haptique répété fatigue et trahit un double appel.',
      );
    });

    test('sans sélection, rien n\'est émis', () async {
      final _RecordingFeedback feedback = _RecordingFeedback();
      final QuizController controller = await loadedController(feedback);

      controller.grade();

      expect(feedback.gradedCalls, isEmpty);
    });
  });
}
