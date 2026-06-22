import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';

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
          loading: () => const _ProfileLoading(),
          error: (Object error, StackTrace _) => PrismStatusView.error(
            onRetry: () => ref.invalidate(meProvider),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.me, required this.mode, required this.onMode});

  final UserProfile me;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final List<_BadgeData> badges = <_BadgeData>[
      _BadgeData(Icons.rocket_launch_rounded, 'Premier décollage', p.primary, me.xp > 0),
      _BadgeData(Icons.local_fire_department_rounded, 'Série de 7 j', p.ember, me.streakDays >= 7),
      _BadgeData(Icons.bolt_rounded, '1 000 XP', p.xpGold, me.xp >= 1000),
      _BadgeData(Icons.diamond_rounded, 'Collectionneur', p.info, me.gems >= 100),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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
                  _initials(me.displayName),
                  style: t.titleLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(me.displayName, style: t.titleLarge),
                    Text(
                      _subtitle(me),
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
            _StatTile(
              label: 'XP total',
              value: '${me.xp}',
              color: p.xpGold,
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(width: 12),
            _StatTile(
              label: 'Série',
              value: '${me.streakDays} j',
              color: p.ember,
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(width: 12),
            _StatTile(
              label: 'Gemmes',
              value: '${me.gems}',
              color: p.info,
              icon: Icons.diamond_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text('Badges', style: t.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final _BadgeData b in badges)
              _Badge(icon: b.icon, label: b.label, color: b.color, locked: !b.unlocked),
          ],
        ),
        const SizedBox(height: 24),

        Text('Préférences', style: t.titleLarge),
        const SizedBox(height: 12),
        PrismCard(
          child: Column(
            children: <Widget>[
              _ThemeRow(mode: mode, onChanged: onMode),
              Divider(color: p.border, height: 24),
              const _PrefRow(
                icon: Icons.notifications_rounded,
                label: 'Rappels quotidiens',
                trailing: 'Bientôt',
              ),
              Divider(color: p.border, height: 24),
              const _PrefRow(
                icon: Icons.language_rounded,
                label: 'Langue',
                trailing: 'Français',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Expanded(
      child: PrismCard(
        variant: PrismCardVariant.tonal,
        accent: color,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: t.titleMedium),
            Text(label, style: t.labelSmall?.copyWith(color: p.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return SizedBox(
      width: 88,
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: locked ? p.surfaceAlt : color.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: locked ? p.border : color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: locked ? p.textSecondary : color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t.labelSmall?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Icon(Icons.dark_mode_rounded, color: p.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('Thème', style: t.bodyLarge)),
        SegmentedButton<ThemeMode>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const <ButtonSegment<ThemeMode>>[
            ButtonSegment<ThemeMode>(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded)),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_rounded),
            ),
            ButtonSegment<ThemeMode>(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded)),
          ],
          selected: <ThemeMode>{mode},
          onSelectionChanged: (Set<ThemeMode> s) => onChanged(s.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.icon, required this.label, required this.trailing});

  final IconData icon;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Icon(icon, color: p.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: t.bodyLarge)),
        Text(trailing, style: t.labelMedium?.copyWith(color: p.textSecondary)),
      ],
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: const <Widget>[
        PrismSkeleton(height: 88),
        SizedBox(height: 16),
        PrismSkeleton(height: 96),
        SizedBox(height: 24),
        PrismSkeleton(width: 120, height: 20),
        SizedBox(height: 12),
        PrismSkeleton(height: 90),
      ],
    );
  }
}

class _BadgeData {
  const _BadgeData(this.icon, this.label, this.color, this.unlocked);

  final IconData icon;
  final String label;
  final Color color;
  final bool unlocked;
}

String _subtitle(UserProfile me) {
  final String level = 'Niveau ${me.level}';
  if (me.handle.isEmpty) {
    return level;
  }
  return '@${me.handle} • $level';
}

String _initials(String name) {
  final List<String> parts =
      name.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  final String a = parts.first.substring(0, 1);
  final String b = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (a + b).toUpperCase();
}
