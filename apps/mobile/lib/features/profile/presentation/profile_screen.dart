import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';

/// Profile — identity, lifetime stats, earned badges and preferences.
/// The theme toggle is wired to [themeModeProvider]; the rest is sample data
/// pending `userRepositoryProvider` in P1.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final ThemeMode mode = ref.watch(themeModeProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
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
                    child: Text('JD',
                        style:
                            t.titleLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Jordan Doe', style: t.titleLarge),
                        Text('@jordan • Niveau 7 · Architecte Junior',
                            style: t.bodySmall?.copyWith(color: p.textSecondary)),
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
                    label: 'XP total', value: '12 480', color: p.xpGold, icon: Icons.bolt_rounded),
                const SizedBox(width: 12),
                _StatTile(
                    label: 'Série',
                    value: '7 j',
                    color: p.ember,
                    icon: Icons.local_fire_department_rounded),
                const SizedBox(width: 12),
                _StatTile(
                    label: 'Concepts',
                    value: '143',
                    color: p.success,
                    icon: Icons.lightbulb_rounded),
              ],
            ),
            const SizedBox(height: 24),

            Text('Badges', style: t.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _Badge(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Premier décollage',
                    color: p.primary),
                _Badge(icon: Icons.bolt_rounded, label: 'Semaine parfaite', color: p.xpGold),
                _Badge(icon: Icons.shield_rounded, label: 'Gouvernance', color: p.info),
                _Badge(
                    icon: Icons.lock_rounded,
                    label: 'À débloquer',
                    color: p.textSecondary,
                    locked: true),
              ],
            ),
            const SizedBox(height: 24),

            Text('Préférences', style: t.titleLarge),
            const SizedBox(height: 12),
            PrismCard(
              child: Column(
                children: <Widget>[
                  _ThemeRow(
                      mode: mode,
                      onChanged: (ThemeMode m) => ref.read(themeModeProvider.notifier).state = m),
                  Divider(color: p.border, height: 24),
                  _PrefRow(
                      icon: Icons.notifications_rounded,
                      label: 'Rappels quotidiens',
                      trailing: 'Bientôt'),
                  Divider(color: p.border, height: 24),
                  _PrefRow(icon: Icons.language_rounded, label: 'Langue', trailing: 'Français'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.label, required this.value, required this.color, required this.icon});
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
  const _Badge({required this.icon, required this.label, required this.color, this.locked = false});
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
          Text(label,
              textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: p.textSecondary)),
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
          style: ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const <ButtonSegment<ThemeMode>>[
            ButtonSegment<ThemeMode>(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded)),
            ButtonSegment<ThemeMode>(
                value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded)),
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
