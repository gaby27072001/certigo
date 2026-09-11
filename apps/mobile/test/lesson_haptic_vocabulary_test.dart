import 'package:certigo/features/lesson/application/lesson_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde de **comportement natif** : le vocabulaire haptique.
///
/// Le retour haptique ne se teste pas « en le sentant » — aucun simulateur ne
/// vibre, et l'appareil du propriétaire n'est pas ici. Mais la vibration
/// *demandée* passe par un canal de plateforme, et ce canal, lui, s'écoute.
///
/// Ces tests interceptent `SystemChannels.platform` et lisent l'argument exact
/// de chaque `HapticFeedback.vibrate`. Ce n'est pas un double posé à côté du
/// code : c'est le message que l'iPhone recevrait.
///
/// ## Le défaut que cette garde ferme
///
/// Mesuré au canal, avant correction :
///
/// | moment | vibration demandée |
/// | --- | --- |
/// | bonne réponse | `mediumImpact` |
/// | mauvaise réponse | `heavyImpact` |
/// | **leçon terminée** | **`lightImpact`** |
///
/// Terminer une leçon entière — le moment le plus gratifiant de
/// l'application — était **la chose la plus faible que le téléphone
/// produise**, plus faible que se tromper sur une seule question.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> emitted;

  setUp(() {
    emitted = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        emitted.add('${call.arguments}');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('l\'instrument sait varier', () {
    // Sans ces témoins, une liste attendue serait indiscernable d'un canal muet
    // qui n'enregistre rien. Voir docs/GOVERNANCE.md §7c.
    test('rien n\'est émis quand rien n\'est demandé', () {
      expect(emitted, isEmpty);
    });

    test('une vibration connue est bien captée, avec son type', () async {
      await HapticFeedback.lightImpact();
      expect(emitted, <String>['HapticFeedbackType.lightImpact']);
    });

    test('le silence explicite n\'émet rien', () {
      const SilentLessonFeedback().completed();
      const SilentLessonFeedback().graded(correct: true);
      expect(emitted, isEmpty);
    });
  });

  group('le vocabulaire iOS de la leçon', () {
    const HapticLessonFeedback feedback = HapticLessonFeedback();

    test('une bonne réponse frappe moyen', () async {
      feedback.graded(correct: true);
      await pumpEventQueue();
      expect(emitted, <String>['HapticFeedbackType.mediumImpact']);
    });

    test('une mauvaise réponse frappe fort', () async {
      feedback.graded(correct: false);
      await pumpEventQueue();
      expect(emitted, <String>['HapticFeedbackType.heavyImpact']);
    });

    test('une leçon terminée est une double frappe ascendante', () async {
      feedback.completed();
      // La seconde frappe est différée : sans cette attente, on ne verrait que
      // la première — et le test passerait en décrivant l'ancien défaut.
      await Future<void>.delayed(HapticLessonFeedback.successBeatGap * 3);
      expect(
        emitted,
        <String>['HapticFeedbackType.lightImpact', 'HapticFeedbackType.mediumImpact'],
        reason: 'Flutter n\'expose pas le motif « succès » d\'iOS ; deux frappes '
            'ascendantes le reconstituent.',
      );
    });

    test('terminer une leçon pèse plus que se tromper', () async {
      feedback.completed();
      await Future<void>.delayed(HapticLessonFeedback.successBeatGap * 3);
      final int completion = emitted.length;

      emitted.clear();
      feedback.graded(correct: false);
      await pumpEventQueue();
      final int wrongAnswer = emitted.length;

      expect(
        completion,
        greaterThan(wrongAnswer),
        reason: 'C\'est l\'inversion que cette garde ferme : la fin de leçon ne '
            'doit jamais se ressentir moins qu\'une erreur.',
      );
    });

    test('la fin de leçon reste sobre — deux frappes, pas davantage', () async {
      feedback.completed();
      await Future<void>.delayed(HapticLessonFeedback.successBeatGap * 5);
      expect(
        emitted,
        hasLength(2),
        reason: 'Un retour haptique qui s\'étire fatigue et cesse d\'être une '
            'récompense.',
      );
    });
  });
}
