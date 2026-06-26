import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the learner wants to do first — mirrors the opening "what now?" question
/// of a returning-user flow, themed for certification tracks.
enum StartChoice { continueTrack, switchTrack, explore }

/// Why the learner is here (multi-select motivation).
enum LearnReason { career, certification, upskill, curiosity, raise, time, other }

/// Daily commitment options, each with a minute target, an XP goal and a mood
/// label (the right-aligned caption on the goal selector).
enum DailyGoalOption { chill, regular, serious, intense }

extension DailyGoalOptionInfo on DailyGoalOption {
  int get minutes => switch (this) {
        DailyGoalOption.chill => 3,
        DailyGoalOption.regular => 10,
        DailyGoalOption.serious => 15,
        DailyGoalOption.intense => 30,
      };

  /// XP goal roughly proportional to the minute target.
  int get xp => switch (this) {
        DailyGoalOption.chill => 20,
        DailyGoalOption.regular => 50,
        DailyGoalOption.serious => 80,
        DailyGoalOption.intense => 150,
      };

  String get label => switch (this) {
        DailyGoalOption.chill => 'Tranquille',
        DailyGoalOption.regular => 'Sérieux',
        DailyGoalOption.serious => 'Intensif',
        DailyGoalOption.intense => 'Extrême',
      };
}

/// Holds the answers gathered during the startup flow and the single
/// [completed] flag that gates entry to the app shell.
///
/// A [ChangeNotifier] (rather than a Riverpod StateNotifier) so it can be handed
/// directly to GoRouter's `refreshListenable`: when [complete] flips the flag,
/// the router's redirect re-runs and lets the learner into the app.
///
/// State is in-memory for now — the flow replays each launch, which is exactly
/// what you want while polishing the onboarding. Persisting "already onboarded"
/// later is a one-line change in [complete] (e.g. shared_preferences).
class OnboardingController extends ChangeNotifier {
  OnboardingController() {
    Future<void>.microtask(_restoreCompletedFlag);
  }

  static const String _completedPrefsKey = 'onboarding_completed';

  bool _completed = false;
  bool get completed => _completed;

  StartChoice _start = StartChoice.continueTrack;
  StartChoice get start => _start;

  final Set<LearnReason> _reasons = <LearnReason>{};
  Set<LearnReason> get reasons => Set<LearnReason>.unmodifiable(_reasons);

  DailyGoalOption? _goal;
  DailyGoalOption? get goal => _goal;

  bool _reminders = true;
  bool get reminders => _reminders;

  void setStart(StartChoice value) {
    _start = value;
    notifyListeners();
  }

  void toggleReason(LearnReason value) {
    if (!_reasons.remove(value)) {
      _reasons.add(value);
    }
    notifyListeners();
  }

  void setGoal(DailyGoalOption value) {
    _goal = value;
    notifyListeners();
  }

  void setReminders(bool value) {
    _reminders = value;
    notifyListeners();
  }

  /// Number of new notions promised for the first week, derived from the daily
  /// goal — used by the "≈ N notions cette semaine" promise screen.
  int get weeklyNotions {
    final int minutes = (_goal ?? DailyGoalOption.regular).minutes;
    return (minutes * 7 / 2).round();
  }

  /// Mark onboarding finished; the router redirect then admits the learner.
  void complete() {
    if (_completed) return;
    _completed = true;
    notifyListeners();
    unawaited(_persistCompletedFlag(value: true));
  }

  /// Reset everything (useful for "recommencer l'introduction" or tests).
  void restart() {
    _completed = false;
    _start = StartChoice.continueTrack;
    _reasons.clear();
    _goal = null;
    _reminders = true;
    notifyListeners();
    unawaited(_persistCompletedFlag(value: false));
  }

  Future<void> _restoreCompletedFlag() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool completed = prefs.getBool(_completedPrefsKey) ?? false;
      if (_completed == completed) return;
      _completed = completed;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[OnboardingController] Failed to restore completion flag: $e');
      debugPrint('$st');
    }
  }

  Future<void> _persistCompletedFlag({required bool value}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedPrefsKey, value);
    } catch (e, st) {
      debugPrint('[OnboardingController] Failed to persist completion flag: $e');
      debugPrint('$st');
    }
  }
}

/// App-wide onboarding state. Read by the startup screens and handed to GoRouter
/// as a `refreshListenable` so completing the flow re-runs the route guard.
final onboardingControllerProvider = ChangeNotifierProvider<OnboardingController>(
  (Ref ref) => OnboardingController(),
);
