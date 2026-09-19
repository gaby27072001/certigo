import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/application/onboarding_controller.dart';

// SharedPreferences keys
const String kPrefDailyGoal = 'pref_daily_goal';
const String kPrefLevel = 'pref_knowledge_level';
const String kPrefDomains = 'pref_domains';
const String kPrefSoundsEnabled = 'pref_sounds';
const String kPrefHapticsEnabled = 'pref_haptics';
const String kPrefStreakReminder = 'pref_streak_reminder';
const String kPrefDisplayName = 'pref_display_name';
const String kPrefHandle = 'pref_handle';
const String kPrefAppLanguage = 'pref_app_language';

// ---------------------------------------------------------------------------
// Extensions for enum labels
// ---------------------------------------------------------------------------

extension KnowledgeLevelInfo on KnowledgeLevel {
  String get label {
    switch (this) {
      case KnowledgeLevel.beginner:
        return 'Débutant 🌱';
      case KnowledgeLevel.intermediate:
        return 'Intermédiaire 🌿';
      case KnowledgeLevel.advanced:
        return 'Avancé 🌳';
      case KnowledgeLevel.expert:
        return 'Expert 🏆';
    }
  }
}

extension AzureDomainInfo on AzureDomain {
  String get label {
    switch (this) {
      case AzureDomain.compute:
        return 'Azure Compute';
      case AzureDomain.storage:
        return 'Azure Storage & DBs';
      case AzureDomain.ai:
        return 'Azure AI & ML';
      case AzureDomain.security:
        return 'Azure Security & Identity';
      case AzureDomain.networking:
        return 'Azure Networking';
      case AzureDomain.devops:
        return 'Azure DevOps';
      case AzureDomain.monitoring:
        return 'Azure Monitoring';
      case AzureDomain.serverless:
        return 'Azure Serverless';
    }
  }
}

// ---------------------------------------------------------------------------
// DailyGoal
// ---------------------------------------------------------------------------

class DailyGoalNotifier extends StateNotifier<DailyGoalOption> {
  DailyGoalNotifier() : super(DailyGoalOption.regular) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? idx = prefs.getInt(kPrefDailyGoal);
    if (idx != null && idx >= 0 && idx < DailyGoalOption.values.length) {
      state = DailyGoalOption.values[idx];
    }
  }

  Future<void> set(DailyGoalOption value) async {
    state = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefDailyGoal, value.index);
  }
}

final StateNotifierProvider<DailyGoalNotifier, DailyGoalOption> dailyGoalProvider =
    StateNotifierProvider<DailyGoalNotifier, DailyGoalOption>((_) => DailyGoalNotifier());

// ---------------------------------------------------------------------------
// KnowledgeLevel
// ---------------------------------------------------------------------------

class KnowledgeLevelNotifier extends StateNotifier<KnowledgeLevel> {
  KnowledgeLevelNotifier() : super(KnowledgeLevel.beginner) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? idx = prefs.getInt(kPrefLevel);
    if (idx != null && idx >= 0 && idx < KnowledgeLevel.values.length) {
      state = KnowledgeLevel.values[idx];
    }
  }

  Future<void> set(KnowledgeLevel value) async {
    state = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefLevel, value.index);
  }
}

final StateNotifierProvider<KnowledgeLevelNotifier, KnowledgeLevel> knowledgeLevelProvider =
    StateNotifierProvider<KnowledgeLevelNotifier, KnowledgeLevel>((_) => KnowledgeLevelNotifier());

// ---------------------------------------------------------------------------
// AzureDomains
// ---------------------------------------------------------------------------

class DomainsNotifier extends StateNotifier<Set<AzureDomain>> {
  DomainsNotifier() : super(const <AzureDomain>{}) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(kPrefDomains);
    if (stored != null && stored.isNotEmpty) {
      final Set<AzureDomain> loaded = <AzureDomain>{};
      for (final String part in stored.split(',')) {
        final int? idx = int.tryParse(part.trim());
        if (idx != null && idx >= 0 && idx < AzureDomain.values.length) {
          loaded.add(AzureDomain.values[idx]);
        }
      }
      state = loaded;
    }
  }

  Future<void> set(Set<AzureDomain> value) async {
    state = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = value.map((AzureDomain d) => d.index.toString()).join(',');
    await prefs.setString(kPrefDomains, encoded);
  }
}

final StateNotifierProvider<DomainsNotifier, Set<AzureDomain>> domainsProvider =
    StateNotifierProvider<DomainsNotifier, Set<AzureDomain>>((_) => DomainsNotifier());

// ---------------------------------------------------------------------------
// SoundsEnabled
// ---------------------------------------------------------------------------

class SoundsEnabledNotifier extends StateNotifier<bool> {
  SoundsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(kPrefSoundsEnabled) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefSoundsEnabled, value);
  }
}

final StateNotifierProvider<SoundsEnabledNotifier, bool> soundsEnabledProvider =
    StateNotifierProvider<SoundsEnabledNotifier, bool>((_) => SoundsEnabledNotifier());

// ---------------------------------------------------------------------------
// HapticsEnabled
// ---------------------------------------------------------------------------

/// La préférence « Vibrations », et **le seul** écrivain de [PrismHaptics].
///
/// Mesuré avant correction : `hapticsEnabled`, `hapticService` et
/// `enableHaptics` n'existaient nulle part dans le dépôt — aucune vibration
/// n'était coupable. Il existait bien un interrupteur intitulé « Sons &
/// vibrations », mais `soundsEnabledProvider` n'était lu que par
/// l'interrupteur lui-même : **il ne commandait rien**. Le libellé promettait
/// une maîtrise des vibrations que le code n'offrait pas.
///
/// La porte est poussée depuis le notifier, pas depuis un widget : une
/// préférence ne doit pas dépendre de la présence à l'écran de l'écran qui la
/// règle. Le chargement initial la pousse aussi, sinon un utilisateur ayant
/// coupé les vibrations les retrouverait à chaque démarrage jusqu'à sa
/// première visite du profil.
class HapticsEnabledNotifier extends StateNotifier<bool> {
  HapticsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool value = prefs.getBool(kPrefHapticsEnabled) ?? true;
    state = value;
    PrismHaptics.enabled = value;
  }

  Future<void> set(bool value) async {
    state = value;
    PrismHaptics.enabled = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefHapticsEnabled, value);
  }
}

final StateNotifierProvider<HapticsEnabledNotifier, bool> hapticsEnabledProvider =
    StateNotifierProvider<HapticsEnabledNotifier, bool>((_) => HapticsEnabledNotifier());

// ---------------------------------------------------------------------------
// StreakReminder
// ---------------------------------------------------------------------------

class StreakReminderNotifier extends StateNotifier<bool> {
  StreakReminderNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(kPrefStreakReminder) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefStreakReminder, value);
  }
}

final StateNotifierProvider<StreakReminderNotifier, bool> streakReminderProvider =
    StateNotifierProvider<StreakReminderNotifier, bool>((_) => StreakReminderNotifier());

// ---------------------------------------------------------------------------
// DisplayName override
// ---------------------------------------------------------------------------

class DisplayNameNotifier extends StateNotifier<String?> {
  DisplayNameNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getString(kPrefDisplayName);
  }

  Future<void> set(String value) async {
    final String trimmed = value.trim();
    state = trimmed.isEmpty ? null : trimmed;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(kPrefDisplayName);
    } else {
      await prefs.setString(kPrefDisplayName, trimmed);
    }
  }
}

final StateNotifierProvider<DisplayNameNotifier, String?> displayNameOverrideProvider =
    StateNotifierProvider<DisplayNameNotifier, String?>((_) => DisplayNameNotifier());

// ---------------------------------------------------------------------------
// Handle override
// ---------------------------------------------------------------------------

class HandleNotifier extends StateNotifier<String?> {
  HandleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getString(kPrefHandle);
  }

  Future<void> set(String value) async {
    final String trimmed = value.trim().toLowerCase();
    state = trimmed.isEmpty ? null : trimmed;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(kPrefHandle);
    } else {
      await prefs.setString(kPrefHandle, trimmed);
    }
  }
}

final StateNotifierProvider<HandleNotifier, String?> handleOverrideProvider =
    StateNotifierProvider<HandleNotifier, String?>((_) => HandleNotifier());

// ---------------------------------------------------------------------------
// AppLanguage
// ---------------------------------------------------------------------------

class AppLanguageNotifier extends StateNotifier<String> {
  AppLanguageNotifier() : super('fr') {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getString(kPrefAppLanguage) ?? 'fr';
  }

  Future<void> set(String value) async {
    state = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefAppLanguage, value);
  }
}

final StateNotifierProvider<AppLanguageNotifier, String> appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, String>((_) => AppLanguageNotifier());
