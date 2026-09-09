import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../application/settings_preferences.dart';
import 'widgets/account_section.dart';
import 'widgets/app_info_section.dart';
import 'widgets/learning_section.dart';
import 'widgets/preference_rows.dart';
import 'widgets/profile_badge.dart';
import 'widgets/profile_loading.dart';
import 'widgets/sign_out_section.dart';
import 'widgets/stat_tile.dart';

/// Profile — identity, lifetime stats, earned badges and preferences. Identity
/// and stats come from `meProvider` (real profile from the API); badges are
/// derived from those stats. The theme toggle is wired to [themeModeProvider].
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final AsyncValue<UserProfile> async = ref.watch(meProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: async.when(
          data: (UserProfile me) => _ProfileContent(
            me: me,
            mode: mode,
            onMode: (ThemeMode m) => ref.read(themeModeProvider.notifier).state = m,
          ),
          loading: () => const ProfileLoading(),
          error: (Object error, StackTrace _) =>
              PrismStatusView.error(onRetry: () => ref.invalidate(meProvider)),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.me, required this.mode, required this.onMode});

  final UserProfile me;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final String? nameOverride = ref.watch(displayNameOverrideProvider);
    final String? handleOverride = ref.watch(handleOverrideProvider);
    final String displayName = nameOverride ?? me.displayName;
    final String handle = handleOverride ?? me.handle;
    final List<BadgeData> badges = <BadgeData>[
      BadgeData(Icons.rocket_launch_rounded, 'Premier décollage', p.primary, me.xp > 0),
      BadgeData(Icons.local_fire_department_rounded, 'Série de 7 j', p.ember, me.streakDays >= 7),
      BadgeData(Icons.bolt_rounded, '1 000 XP', p.xpGold, me.xp >= 1000),
      BadgeData(Icons.diamond_rounded, 'Collectionneur', p.info, me.gems >= 100),
    ];

    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
      children: <Widget>[
        // Identity -------------------------------------------------------
        PrismCard(
          elevation: 2,
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 32,
                backgroundColor: p.primarySoft,
                child: Text(
                  _initials(displayName),
                  style: t.titleLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(displayName, style: t.titleLarge),
                    Text(
                      _subtitleFromParts(handle, me.level),
                      style: t.bodySmall?.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lifetime stats -------------------------------------------------
        Row(
          children: <Widget>[
            StatTile(
              label: 'XP total',
              value: '${me.xp}',
              color: p.xpGold,
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(width: 12),
            StatTile(
              label: 'Série',
              value: '${me.streakDays} j',
              color: p.ember,
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(width: 12),
            StatTile(
              label: 'Gemmes',
              value: '${me.gems}',
              color: p.info,
              icon: Icons.diamond_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),

        const PrismSectionHeader(
          title: 'Badges',
          subtitle: 'Tes jalons de progression',
          icon: Icons.workspace_premium_rounded,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final BadgeData b in badges)
              ProfileBadge(icon: b.icon, label: b.label, color: b.color, locked: !b.unlocked),
          ],
        ),
        const SizedBox(height: 12),
        PrismButton.secondary(
          label: 'Tous les succès',
          icon: Icons.chevron_right_rounded,
          onPressed: () => context.push(Routes.achievements),
        ),
        const SizedBox(height: 12),
        PrismButton.secondary(
          label: 'Partager le score du jour',
          icon: Icons.share_rounded,
          onPressed: () => context.push(Routes.dailyShare),
        ),
        const SizedBox(height: 24),

        // Mon compte -----------------------------------------------------
        const PrismSectionHeader(title: 'Mon compte', icon: Icons.person_rounded),
        const SizedBox(height: 12),
        AccountSection(me: me),
        const SizedBox(height: 24),

        // Apprentissage --------------------------------------------------
        const PrismSectionHeader(title: 'Apprentissage', icon: Icons.school_rounded),
        const SizedBox(height: 12),
        const LearningSection(),
        const SizedBox(height: 24),

        // Préférences ----------------------------------------------------
        const PrismSectionHeader(title: 'Préférences', icon: Icons.tune_rounded),
        const SizedBox(height: 12),
        PrismCard(
          child: Column(
            children: <Widget>[
              ThemeRow(mode: mode, onChanged: onMode),
              Divider(color: p.border, height: 24),
              const NotificationPrefRow(),
              Divider(color: p.border, height: 24),
              SwitchPrefRow(
                icon: Icons.local_fire_department_rounded,
                label: 'Rappel de série',
                provider: streakReminderProvider,
                onChanged: (bool v, WidgetRef r) => r.read(streakReminderProvider.notifier).set(v),
              ),
              Divider(color: p.border, height: 24),
              SwitchPrefRow(
                icon: Icons.volume_up_rounded,
                label: 'Sons & vibrations',
                provider: soundsEnabledProvider,
                onChanged: (bool v, WidgetRef r) => r.read(soundsEnabledProvider.notifier).set(v),
              ),
              Divider(color: p.border, height: 24),
              const LanguagePrefRow(),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Application ----------------------------------------------------
        const PrismSectionHeader(title: 'Application', icon: Icons.info_outline_rounded),
        const SizedBox(height: 12),
        const AppInfoSection(),

        // Sign-out -------------------------------------------------------
        const SignOutSection(),
      ],
    );
  }
}

String _subtitleFromParts(String handle, int level) {
  final String lvl = 'Niveau $level';
  if (handle.isEmpty) return lvl;
  return '@$handle • $lvl';
}

String _initials(String name) {
  final List<String> parts =
      name.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final String a = parts.first.substring(0, 1);
  final String b = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (a + b).toUpperCase();
}
