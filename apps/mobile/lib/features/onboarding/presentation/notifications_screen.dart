import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import '../../notifications/notification_service.dart';
import 'onboarding_common.dart';

/// The notifications primer — explains the value of a daily reminder before the
/// OS permission prompt and lets the learner opt in or out.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    void go() => context.go(OnboardingRoutes.widget);

    return OnboardingScaffold(
      progress: 0.70,
      onBack: () => context.go(OnboardingRoutes.goal),
      primaryLabel: 'ACTIVER LES RAPPELS',
      onPrimary: () async {
        try {
          final bool scheduled = await NotificationService.scheduleDailyReminder(
            NotificationService.defaultReminderTime,
          );
          c.setReminders(scheduled);
          if (!context.mounted) return;
          if (!scheduled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notifications refusées. Tu pourras les activer dans les réglages.',
                ),
              ),
            );
          }
          go();
        } on Object catch (error, stackTrace) {
          c.setReminders(false);
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'certigo.notifications',
              context: ErrorDescription(
                'while requesting onboarding notification permission',
              ),
            ),
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d’activer les rappels pour le moment.'),
            ),
          );
        }
      },
      secondary: TextButton(
        onPressed: () {
          c.setReminders(false);
          go();
        },
        child: Text('Plus tard', style: t.labelLarge?.copyWith(color: p.textSecondary)),
      ),
      scrollable: false,
      child: Column(
        children: <Widget>[
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: p.primary.withOpacity(0.12), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              Icons.notifications_active_rounded,
              color: p.primary,
              size: 46,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Reste régulier grâce aux rappels',
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Un petit rappel par jour, et la régularité fait le reste. '
            'En l’activant, il sera programmé chaque jour à 19 h. '
            'Tu pourras modifier cette heure dans ton profil.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.45),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
