import 'package:flutter/services.dart';

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

/// Real device feedback: haptics via [HapticFeedback] + a [SoundPlayer] cue.
///
/// Every haptic call is best-effort — wrapped so a missing platform channel
/// (e.g. in a pure unit test) can never break a lesson.
class HapticLessonFeedback implements LessonFeedback {
  const HapticLessonFeedback({this._sound = const NullSoundPlayer()});

  final SoundPlayer _sound;

  @override
  void graded({required bool correct}) {
    if (correct) {
      _safe(HapticFeedback.mediumImpact);
      _sound.play(LessonSound.correct);
    } else {
      _safe(HapticFeedback.heavyImpact);
      _sound.play(LessonSound.incorrect);
    }
  }

  @override
  void completed() {
    _safe(HapticFeedback.lightImpact);
    _sound.play(LessonSound.complete);
  }

  void _safe(void Function() action) {
    try {
      action();
    } catch (_) {
      // Haptics are a nicety; never let them surface as a lesson error.
    }
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
