import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the learner wants to do first — mirrors the opening "what now?" question
/// of a returning-user flow, themed for certification tracks.
enum StartChoice { continueTrack, switchTrack, explore }

/// Why the learner is here (multi-select motivation).
enum LearnReason { career, certification, upskill, curiosity, raise, time, other }

/// Azure service domains the learner is interested in (multi-select).
enum AzureDomain { compute, storage, ai, security, networking, devops, monitoring, serverless }

/// Self-reported Azure knowledge level (single-select).
enum KnowledgeLevel { beginner, intermediate, advanced, expert }

/// Daily commitment options, each with a minute target, an XP goal and a mood
/// label (the right-aligned caption on the goal selector).
enum DailyGoalOption { chill, regular, serious, intense }

/// The certification the learner is aiming for — the Certigo equivalent of the
/// "which language?" question that opens the reference flow.
enum TargetCertification { az900, ai900, dp900, sc900, az104 }

extension TargetCertificationInfo on TargetCertification {
  /// Exam code shown as the bold tile label (e.g. "AZ-900").
  String get code => switch (this) {
        TargetCertification.az900 => 'AZ-900',
        TargetCertification.ai900 => 'AI-900',
        TargetCertification.dp900 => 'DP-900',
        TargetCertification.sc900 => 'SC-900',
        TargetCertification.az104 => 'AZ-104',
      };

  /// Human-readable exam title (the tile subtitle / trailing caption).
  String get title => switch (this) {
        TargetCertification.az900 => 'Azure Fundamentals',
        TargetCertification.ai900 => 'AI Fundamentals',
        TargetCertification.dp900 => 'Data Fundamentals',
        TargetCertification.sc900 => 'Security Fundamentals',
        TargetCertification.az104 => 'Azure Administrator',
      };

  /// Index into `PrismColors.domainAccents` used for the leading accent chip.
  int get domainIndex => switch (this) {
        TargetCertification.az900 => 0,
        TargetCertification.ai900 => 3,
        TargetCertification.dp900 => 4,
        TargetCertification.sc900 => 5,
        TargetCertification.az104 => 1,
      };
}

/// How the learner first heard about Certigo (single-select attribution).
enum AttributionSource { newsBlog, friendsFamily, search, youtube, appStore, social, tiktok, other }

/// The plan the learner picks on the paywall (placeholder — no billing yet).
enum PremiumChoice { premium, free }

/// Where the learner wants to begin their track (single-select).
enum StartMode { scratch, findLevel }

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

  final Set<AzureDomain> _domains = <AzureDomain>{};
  Set<AzureDomain> get domains => Set<AzureDomain>.unmodifiable(_domains);

  KnowledgeLevel? _level;
  KnowledgeLevel? get level => _level;

  DailyGoalOption? _goal;
  DailyGoalOption? get goal => _goal;

  bool _reminders = true;
  bool get reminders => _reminders;

  TargetCertification? _targetCertification;
  TargetCertification? get targetCertification => _targetCertification;

  AttributionSource? _attributionSource;
  AttributionSource? get attributionSource => _attributionSource;

  PremiumChoice? _premiumChoice;
  PremiumChoice? get premiumChoice => _premiumChoice;

  StartMode? _startMode;
  StartMode? get startMode => _startMode;

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

  void toggleDomain(AzureDomain value) {
    if (!_domains.remove(value)) {
      _domains.add(value);
    }
    notifyListeners();
  }

  void setLevel(KnowledgeLevel value) {
    _level = value;
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

  void setTargetCertification(TargetCertification value) {
    _targetCertification = value;
    notifyListeners();
  }

  void setAttributionSource(AttributionSource value) {
    _attributionSource = value;
    notifyListeners();
  }

  void setPremiumChoice(PremiumChoice value) {
    _premiumChoice = value;
    notifyListeners();
  }

  void setStartMode(StartMode value) {
    _startMode = value;
    notifyListeners();
  }

  /// Starting Readiness Score, credited from the self-reported knowledge level —
  /// powers the closing "tu démarres à X !" reaction. A learner who already
  /// knows some notions never starts from zero.
  int get readinessScore => switch (_level) {
        KnowledgeLevel.beginner => 8,
        KnowledgeLevel.intermediate => 22,
        KnowledgeLevel.advanced => 40,
        KnowledgeLevel.expert => 58,
        null => 5,
      };

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
    _domains.clear();
    _level = null;
    _goal = null;
    _reminders = true;
    _targetCertification = null;
    _attributionSource = null;
    _premiumChoice = null;
    _startMode = null;
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
