import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../notifications/notification_service.dart';

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

/// Interactive row that lets the user schedule a daily reminder.
class NotificationPrefRow extends StatefulWidget {
  const NotificationPrefRow({super.key});

  @override
  State<NotificationPrefRow> createState() => _NotificationPrefRowState();
}

class _NotificationPrefRowState extends State<NotificationPrefRow> {
  TimeOfDay? _time;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTime();
  }

  Future<void> _loadSavedTime() async {
    try {
      final TimeOfDay? stored = await NotificationService.loadDailyReminderTime();
      if (stored != null && mounted) setState(() => _time = stored);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'certigo.notifications',
          context: ErrorDescription('while restoring reminder preference'),
        ),
      );
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? NotificationService.defaultReminderTime,
    );
    if (picked == null || !mounted) return;

    try {
      final bool scheduled = await NotificationService.scheduleDailyReminder(
        picked,
      );
      if (!scheduled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autorise les notifications pour activer ce rappel.'),
          ),
        );
        return;
      }
      if (mounted) setState(() => _time = picked);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'certigo.notifications',
          context: ErrorDescription('while scheduling daily reminder'),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de programmer ce rappel pour le moment.'),
        ),
      );
    }
  }

  String get _trailingLabel {
    if (!_loaded) return '…';
    if (_time == null) return 'Désactivé';
    final String h = _time!.hour.toString().padLeft(2, '0');
    final String m = _time!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(PrismRadii.sm),
      child: Row(
        children: <Widget>[
          Icon(Icons.notifications_rounded, color: p.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Rappels quotidiens', style: t.bodyLarge)),
          Text(_trailingLabel, style: t.labelMedium?.copyWith(color: p.primary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 18),
        ],
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
        Switch(value: value, onChanged: (bool v) => onChanged(v, ref)),
      ],
    );
  }
}

class LanguagePrefRow extends StatelessWidget {
  const LanguagePrefRow({super.key});

  Future<void> _showPicker(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Text('✅'),
              title: const Text('Français'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            ListTile(
              leading: const Text('🔒'),
              title: const Text('English'),
              trailing: _ComingSoonChip(),
              enabled: false,
            ),
            ListTile(
              leading: const Text('🔒'),
              title: const Text('Español'),
              trailing: _ComingSoonChip(),
              enabled: false,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
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

class _ComingSoonChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.xs,
        vertical: PrismSpacing.debt3,
      ),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(PrismRadii.md),
      ),
      child: Text(
        'Bientôt',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.textSecondary),
      ),
    );
  }
}
