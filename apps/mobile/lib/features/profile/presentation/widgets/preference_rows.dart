import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import 'profile_sheets.dart';

class ThemeRow extends StatelessWidget {
  const ThemeRow({super.key, required this.mode, required this.onChanged});

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

class NotificationPrefRow extends StatelessWidget {
  const NotificationPrefRow({super.key});

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 12,
        onTap: () => context.push(Routes.notifications),
        leading: Icon(Icons.notifications_rounded, color: p.textSecondary),
        title: Text('Notifications et rappels', style: t.bodyLarge),
        subtitle: const Text('Réglages serveur, aperçu et rappels sur cet appareil'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class SwitchPrefRow extends ConsumerWidget {
  const SwitchPrefRow({
    super.key,
    required this.icon,
    required this.label,
    required this.provider,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final ProviderListenable<bool> provider;
  final void Function(bool, WidgetRef) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool value = ref.watch(provider);
    return Row(
      children: <Widget>[
        Icon(icon, color: p.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: t.bodyLarge)),
        // `adaptive` renders the platform's own switch — a Cupertino switch on
        // iOS, where the owner tests. A Material switch there is one of the
        // clearest "this is not a native app" tells.
        Switch.adaptive(value: value, onChanged: (bool v) => onChanged(v, ref)),
      ],
    );
  }
}

class LanguagePrefRow extends StatelessWidget {
  const LanguagePrefRow({super.key});

  Future<void> _showPicker(BuildContext context) async {
    // Only French ships today, so this is a statement of availability rather
    // than a choice. It still uses the Prism sheet so it matches every other
    // picker in the Profile instead of a stock Material dialog.
    await showProfileChoiceSheet<String>(
      context: context,
      title: 'Langue',
      selected: 'fr',
      options: const <ProfileOption<String>>[
        ProfileOption<String>(value: 'fr', label: 'Français', leading: Text('🇫🇷')),
        ProfileOption<String>(
          value: 'en',
          label: 'English',
          leading: Text('🔒'),
          trailing: 'Bientôt',
        ),
        ProfileOption<String>(
          value: 'es',
          label: 'Español',
          leading: Text('🔒'),
          trailing: 'Bientôt',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(PrismRadii.sm),
      child: Row(
        children: <Widget>[
          Icon(Icons.language_rounded, color: p.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Langue', style: t.bodyLarge)),
          Text('Français', style: t.labelMedium?.copyWith(color: p.primary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 18),
        ],
      ),
    );
  }
}
