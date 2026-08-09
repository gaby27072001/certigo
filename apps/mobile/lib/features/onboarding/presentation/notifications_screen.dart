import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// The notifications primer — explains the value of a daily reminder before the
/// (future) OS permission prompt, and lets the learner opt in or out. The
/// `permission_handler` package isn't in the app's dependencies, so this stays a
/// visual primer: the choice is stored on the controller, no real OS permission
/// is requested yet.
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
      onPrimary: () {
        c.setReminders(true);
        go();
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
            child: Icon(Icons.notifications_active_rounded, color: p.primary, size: 46),
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
            'On te proposera le moment idéal pour ta leçon.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.45),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
