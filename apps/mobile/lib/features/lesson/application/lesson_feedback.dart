import 'package:prism_ui/prism_ui.dart';

/// The meaningful audio-haptic moments of a lesson (§3.14 — son & haptique).
enum LessonSound { correct, incorrect, complete }

/// Plays a short sound effect. A seam, not an implementation: real audio needs
/// bundled assets + an audio engine (deferred to keep CI asset-free), so the
/// default is [NullSoundPlayer]. Wiring a real player later is one override.
abstract interface class SoundPlayer {
  void play(LessonSound sound);
}

/// The asset-free default: every cue is a silent no-op.
class NullSoundPlayer implements SoundPlayer {
  const NullSoundPlayer();

  @override
  void play(LessonSound sound) {}
}

/// Fires the "juicy" feedback that makes a check feel rewarding: a haptic pulse
/// (free, asset-less, available on iOS *and* Android) plus an optional sound.
///
/// Injected into the controller so it can be swapped for [SilentLessonFeedback]
/// (reduce-motion / tests) — the single source of truth for *when* feedback
/// happens stays in the domain layer, not scattered across widgets.
abstract interface class LessonFeedback {
  /// A check was graded — celebrate or commiserate.
  void graded({required bool correct});

  /// The whole lesson was completed.
  void completed();
}

/// Real device feedback: haptics via [PrismHaptics] + a [SoundPlayer] cue.
///
/// Les vibrations passent par [PrismHaptics], la **porte unique** du dépôt :
/// c'est elle qui applique la préférence « Vibrations » du profil, et c'est
/// elle qui conserve le caractère best-effort — un canal de plateforme absent
/// (en test unitaire pur, par exemple) ne peut pas casser une leçon.
///
/// Le `_safe` local qui tenait ce second rôle a été remplacé par cette porte.
/// Le **vocabulaire** ci-dessous est inchangé : il est épinglé au canal de
/// plateforme par `lesson_haptic_vocabulary_test.dart`.
class HapticLessonFeedback implements LessonFeedback {
  const HapticLessonFeedback({this._sound = const NullSoundPlayer()});

  /// Écart entre les deux frappes de la fin de leçon.
  ///
  /// Court assez pour être perçu comme **un seul** événement, long assez pour
  /// que les deux frappes ne se confondent pas.
  static const Duration successBeatGap = Duration(milliseconds: 90);

  final SoundPlayer _sound;

  @override
  void graded({required bool correct}) {
    if (correct) {
      PrismHaptics.medium();
      _sound.play(LessonSound.correct);
    } else {
      PrismHaptics.heavy();
      _sound.play(LessonSound.incorrect);
    }
  }

  @override
  void completed() {
    // Mesuré au canal de plateforme : cette fin de leçon émettait un seul
    // `lightImpact` — soit **moins** qu'une mauvaise réponse (`heavyImpact`).
    // Le moment le plus gratifiant de l'application était le plus faible que
    // le téléphone produise.
    //
    // Flutter n'expose pas `UINotificationFeedbackGenerator.success`, dont le
    // motif iOS est une **double frappe ascendante**. On le reconstitue avec
    // les deux seules briques disponibles : léger, puis moyen.
    //
    // Deux frappes, une fois par leçon : c'est ce qui distingue une
    // célébration d'un choc, sans tomber dans le retour haptique permanent
    // qui finit par fatiguer.
    PrismHaptics.light();
    Future<void>.delayed(successBeatGap, PrismHaptics.medium);
    _sound.play(LessonSound.complete);
  }
}

/// No feedback at all — for reduce-motion preferences and deterministic tests.
class SilentLessonFeedback implements LessonFeedback {
  const SilentLessonFeedback();

  @override
  void graded({required bool correct}) {}

  @override
  void completed() {}
}
