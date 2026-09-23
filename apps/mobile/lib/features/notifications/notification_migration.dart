import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The legacy settings had no owner. Claim them once for the first signed-in
/// account, before network I/O, and never replay them into another account.
class LegacyNotificationChoice {
  const LegacyNotificationChoice(
      {required this.owner,
      required this.enabled,
      required this.streakAlerts,
      this.hour,
      this.minute});

  final String owner;
  final bool? enabled;
  final bool? streakAlerts;
  final int? hour;
  final int? minute;
  bool get needsHourConfirmation => minute != null && minute != 0;
  String get timeLabel => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  NotificationSettings applyTo(NotificationSettings server) => server.copyWith(
        enabled: enabled,
        streakAlerts: streakAlerts,
        preferredHour: hour,
      );

  static const String _ownerKey = 'notification_migration_owner';
  static const List<String> _legacyKeys = <String>[
    'daily_reminder_schedule',
    'daily_reminder_time',
    'pref_streak_reminder',
  ];

  static Future<bool> preserveUntilSessionRestored() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.containsKey(_legacyKeys[0]) || prefs.containsKey(_legacyKeys[1])) &&
        prefs.getBool(_legacyKeys[2]) != false;
  }

  static Future<LegacyNotificationChoice?> load(String owner) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notification_migrated:$owner') == true) return null;
    final String? claimedOwner = prefs.getString(_ownerKey);
    if (claimedOwner != null && claimedOwner != owner) return null;
    final String? stored = prefs.getString(_legacyKeys[0]) ?? prefs.getString(_legacyKeys[1]);
    final bool? streak = prefs.getBool(_legacyKeys[2]);
    if (stored == null && streak == null) return null;
    int? hour;
    int? minute;
    if (stored != null) {
      final List<String> parts = stored.split('|').first.split(':');
      hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
      minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw const ParseFailure();
      }
    }
    if (claimedOwner == null && !await prefs.setString(_ownerKey, owner)) {
      throw const CacheFailure();
    }
    return LegacyNotificationChoice(
      owner: owner,
      enabled: streak == false
          ? false
          : stored != null
              ? true
              : null,
      streakAlerts: streak,
      hour: hour,
      minute: minute,
    );
  }

  /// An explicit disable remains authoritative while its POST is offline.
  Future<void> disableLocally() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_ownerKey) != owner ||
        !await prefs.setBool('pref_streak_reminder', false)) {
      throw const CacheFailure();
    }
  }

  /// Called only after a successful, parsed server response to the full POST.
  Future<void> complete() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_ownerKey) != owner) throw const CacheFailure();
    if (!await prefs.setBool('notification_migrated:$owner', true)) {
      throw const CacheFailure();
    }
    for (final String key in _legacyKeys) {
      if (prefs.containsKey(key) && !await prefs.remove(key)) throw const CacheFailure();
    }
  }
}
