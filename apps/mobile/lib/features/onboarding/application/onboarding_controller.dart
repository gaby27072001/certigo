import 'dart:async';

import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

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
enum TargetCertification { az900, ai900, ai901, dp900, sc900, az104 }

const List<TargetCertification> availableTargetCertifications = <TargetCertification>[
  TargetCertification.az900,
  TargetCertification.ai901,
  TargetCertification.dp900,
  TargetCertification.sc900,
  TargetCertification.az104,
];

extension TargetCertificationInfo on TargetCertification {
  /// Identifiant historique (mode `legacy`) — aussi le slug du catalogue
  /// versionné. Ne jamais l'envoyer tel quel à l'API : résoudre l'entrée réelle
  /// du catalogue via [matchesTrack] et envoyer son `id`.
  String get trackId => switch (this) {
        TargetCertification.az900 => 'az-900',
        TargetCertification.ai900 => 'ai-900',
        TargetCertification.ai901 => 'ai-901',
        TargetCertification.dp900 => 'dp-900',
        TargetCertification.sc900 => 'sc-900',
        TargetCertification.az104 => 'az-104',
      };

  /// Exam code shown as the bold tile label (e.g. "AZ-900").
  String get code => switch (this) {
        TargetCertification.az900 => 'AZ-900',
        TargetCertification.ai900 => 'AI-900',
        TargetCertification.ai901 => 'AI-901',
        TargetCertification.dp900 => 'DP-900',
        TargetCertification.sc900 => 'SC-900',
        TargetCertification.az104 => 'AZ-104',
      };

  /// Human-readable exam title (the tile subtitle / trailing caption).
  String get title => switch (this) {
        TargetCertification.az900 => 'Microsoft Azure Fundamentals',
        TargetCertification.ai900 => 'Microsoft Azure AI Fundamentals',
        TargetCertification.ai901 => 'Microsoft Azure AI Fundamentals',
        TargetCertification.dp900 => 'Microsoft Azure Data Fundamentals',
        TargetCertification.sc900 => 'Security Fundamentals',
        TargetCertification.az104 => 'Microsoft Azure Administrator',
      };

  bool get isAvailableForNewLearners => this != TargetCertification.ai900;

  /// Whether [track] is this certification, whichever id namespace the backend
  /// serves.
  ///
  /// Invariant de contenu : l'id de catalogue dépend de `CONTENT_REPOSITORY_MODE`.
  /// En `legacy` le backend sert l'id nu (`az-900`) ; en `versioned` il sert un id
  /// namespacé (`microsoft.az-900.track.main`). Comparer [trackId] à `track.id`
  /// ne marche donc qu'en `legacy` et rend l'onboarding infranchissable partout
  /// ailleurs. Le code d'examen et le slug sont stables dans les deux modes :
  /// c'est sur eux qu'on résout, l'id nu ne servant plus que de repli.
  bool matchesTrack(TrackSummary track) {
    final String expected = trackId.toLowerCase();
    if (track.id.toLowerCase() == expected) return true;
    if ((track.slug ?? '').toLowerCase() == expected) return true;
    final String examCode = code.toLowerCase();
    if (track.code.toLowerCase() == examCode) return true;
    if ((track.officialCode ?? '').toLowerCase() == examCode) return true;
    return false;
  }

  /// Index into `PrismColors.domainAccents` used for the leading accent chip.
  int get domainIndex => switch (this) {
        TargetCertification.az900 => 0,
        TargetCertification.ai900 => 3,
        TargetCertification.ai901 => 3,
        TargetCertification.dp900 => 4,
        TargetCertification.sc900 => 5,
        TargetCertification.az104 => 1,
      };
}

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
class OnboardingController extends ChangeNotifier {
  OnboardingController({String? ownerId}) : _ownerId = _normalizeOwner(ownerId);

  static const String _completedPrefsPrefix = 'onboarding_completed';

  String? _ownerId;

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

  /// Mark onboarding finished; the router redirect then admits the learner.
  Future<void> complete() async {
    if (_completed) return;
    if (_ownerId == null) {
      throw StateError('An authenticated account is required to complete onboarding.');
    }
    await _persistCompletedFlag(value: true);
    _completed = true;
    notifyListeners();
  }

  /// Reset everything (useful for "recommencer l'introduction" or tests).
  Future<void> restart() async {
    _completed = false;
    _start = StartChoice.continueTrack;
    _reasons.clear();
    _domains.clear();
    _level = null;
    _goal = null;
    _reminders = true;
    _targetCertification = null;
    notifyListeners();
    if (_ownerId != null) {
      await _persistCompletedFlag(value: false);
    }
  }

  Future<void> restoreForOwner(String? value) async {
    final String? ownerId = _normalizeOwner(value);
    if (ownerId == null) {
      if (_completed) {
        _completed = false;
        notifyListeners();
      }
      return;
    }
    _ownerId = ownerId;
    if (_completed) {
      _completed = false;
      notifyListeners();
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool completed = prefs.getBool(_keyFor(ownerId)) ?? false;
      if (_ownerId != ownerId) return;
      if (_completed == completed) return;
      _completed = completed;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[OnboardingController] Failed to restore completion flag: $e');
      debugPrint('$st');
    }
  }

  Future<void> _persistCompletedFlag({required bool value}) async {
    final String ownerId = _ownerId!;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool saved = await prefs.setBool(_keyFor(ownerId), value);
      if (!saved) {
        throw StateError('Unable to persist onboarding completion.');
      }
    } catch (e, st) {
      debugPrint('[OnboardingController] Failed to persist completion flag: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  static String _keyFor(String ownerId) => '$_completedPrefsPrefix:$ownerId';

  static String? _normalizeOwner(String? value) {
    final String normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}

/// App-wide onboarding state. Read by the startup screens and handed to GoRouter
/// as a `refreshListenable` so completing the flow re-runs the route guard.
final onboardingControllerProvider = ChangeNotifierProvider<OnboardingController>(
  (Ref ref) {
    final OnboardingController controller = OnboardingController();
    ref.listen<AuthState>(authControllerProvider, (_, AuthState next) {
      if (next is Authenticated) {
        unawaited(controller.restoreForOwner(next.session.userId));
      }
    });
    final AuthState current = ref.read(authControllerProvider);
    if (current is Authenticated) {
      unawaited(controller.restoreForOwner(current.session.userId));
    }
    return controller;
  },
);
