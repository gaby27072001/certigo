import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'notification_service.dart';
import 'notification_migration.dart';

final notificationMutationProvider = StateProvider.autoDispose<bool>((Ref ref) {
  ref.watch(activeTrackOwnerIdProvider);
  return false;
});

final legacyNotificationChoiceProvider =
    FutureProvider.autoDispose<LegacyNotificationChoice?>((Ref ref) async {
  final String? owner = ref.watch(activeTrackOwnerIdProvider);
  return owner == null ? null : LegacyNotificationChoice.load(owner);
});

final notificationSettingsProvider =
    FutureProvider.autoDispose<NotificationSettings>((Ref ref) async {
  final String? owner = ref.watch(activeTrackOwnerIdProvider);
  if (owner == null) throw const AuthFailure();
  final NotificationRepository repository = ref.watch(notificationRepositoryProvider);
  bool disposed = false;
  ref.onDispose(() => disposed = true);
  final LegacyNotificationChoice? legacy = await ref.watch(legacyNotificationChoiceProvider.future);
  NotificationSettings settings = (await repository.getSettings()).when(
    success: (NotificationSettings settings) => settings,
    failure: (Failure failure) => throw failure,
  );
  if (legacy != null && !legacy.needsHourConfirmation) {
    if (disposed || ref.read(activeTrackOwnerIdProvider) != owner) throw const AuthFailure();
    settings = (await repository.updateSettings(legacy.applyTo(settings))).when(
      success: (NotificationSettings saved) => saved,
      failure: (Failure failure) => throw failure,
    );
    await legacy.complete();
    await NotificationService.cancelDailyReminder();
    if (!disposed) ref.invalidate(legacyNotificationChoiceProvider);
  }
  return settings;
});

final notificationPlanProvider = FutureProvider.autoDispose<NotificationPlan>((Ref ref) async {
  final String? owner = ref.watch(activeTrackOwnerIdProvider);
  if (owner == null) throw const AuthFailure();
  return (await ref.watch(notificationRepositoryProvider).getPlan()).when(
    success: (NotificationPlan plan) => plan,
    failure: (Failure failure) => throw failure,
  );
});

/// Also exposed on the screen: a plugin/storage failure must be visible, not
/// just logged by the bootstrap lifecycle observer.
final retireLegacyReminderProvider = FutureProvider.autoDispose<void>((Ref ref) {
  return NotificationService.reconcileLifecycle(ref.watch(activeTrackOwnerIdProvider));
});
