import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../notifications/notification_service.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../application/settings_preferences.dart';

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
            onMode: (ThemeMode m) =>
                ref.read(themeModeProvider.notifier).state = m,
          ),
          loading: () => const _ProfileLoading(),
          error: (Object error, StackTrace _) =>
              PrismStatusView.error(onRetry: () => ref.invalidate(meProvider)),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({
    required this.me,
    required this.mode,
    required this.onMode,
  });

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
    final List<_BadgeData> badges = <_BadgeData>[
      _BadgeData(
        Icons.rocket_launch_rounded,
        'Premier décollage',
        p.primary,
        me.xp > 0,
      ),
      _BadgeData(
        Icons.local_fire_department_rounded,
        'Série de 7 j',
        p.ember,
        me.streakDays >= 7,
      ),
      _BadgeData(Icons.bolt_rounded, '1 000 XP', p.xpGold, me.xp >= 1000),
      _BadgeData(
        Icons.diamond_rounded,
        'Collectionneur',
        p.info,
        me.gems >= 100,
      ),
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
                  _initials(displayName),
                  style: t.titleLarge?.copyWith(
                    color: p.primary,
                    fontWeight: FontWeight.w800,
                  ),
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
              _Badge(
                icon: b.icon,
                label: b.label,
                color: b.color,
                locked: !b.unlocked,
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismButton.secondary(
          label: 'Tous les succès',
          icon: Icons.chevron_right_rounded,
          onPressed: () => context.go(Routes.achievements),
        ),
        const SizedBox(height: 12),
        PrismButton.secondary(
          label: 'Partager le score du jour',
          icon: Icons.share_rounded,
          onPressed: () => context.go(Routes.dailyShare),
        ),
        const SizedBox(height: 24),

        // Mon compte -----------------------------------------------------
        Text('Mon compte', style: t.titleLarge),
        const SizedBox(height: 12),
        _AccountSection(me: me),
        const SizedBox(height: 24),

        // Apprentissage --------------------------------------------------
        Text('Apprentissage', style: t.titleLarge),
        const SizedBox(height: 12),
        const _LearningSection(),
        const SizedBox(height: 24),

        // Préférences ----------------------------------------------------
        Text('Préférences', style: t.titleLarge),
        const SizedBox(height: 12),
        PrismCard(
          child: Column(
            children: <Widget>[
              _ThemeRow(mode: mode, onChanged: onMode),
              Divider(color: p.border, height: 24),
              const _NotificationPrefRow(),
              Divider(color: p.border, height: 24),
              _SwitchPrefRow(
                icon: Icons.local_fire_department_rounded,
                label: 'Rappel de série',
                provider: streakReminderProvider,
                onChanged: (bool v, WidgetRef r) =>
                    r.read(streakReminderProvider.notifier).set(v),
              ),
              Divider(color: p.border, height: 24),
              _SwitchPrefRow(
                icon: Icons.volume_up_rounded,
                label: 'Sons & vibrations',
                provider: soundsEnabledProvider,
                onChanged: (bool v, WidgetRef r) =>
                    r.read(soundsEnabledProvider.notifier).set(v),
              ),
              Divider(color: p.border, height: 24),
              const _LanguagePrefRow(),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Application ----------------------------------------------------
        Text('Application', style: t.titleLarge),
        const SizedBox(height: 12),
        const _AppInfoSection(),

        // Sign-out -------------------------------------------------------
        const _SignOutSection(),
      ],
    );
  }
}

/// "Se déconnecter" — shown only when real authentication is wired (Entra
/// configured, or the auth UI is force-enabled for a build). In dev/passthrough
/// builds there is no real session to end, so the row stays hidden.
class _SignOutSection extends ConsumerWidget {
  const _SignOutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(AppEnv.entraConfigured || AppEnv.forceAuthUi)) {
      return const SizedBox.shrink();
    }
    final PrismColorScheme p = context.prism;
    final AuthState state = ref.watch(authControllerProvider);
    final bool busy = state is AuthLoading;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: PrismCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PrismButton(
              label: 'Se déconnecter',
              variant: PrismButtonVariant.secondary,
              tone: p.error,
              icon: Icons.logout_rounded,
              loading: busy,
              onPressed: busy
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
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
              border: Border.all(
                color: locked ? p.border : color.withOpacity(0.4),
              ),
            ),
            child: Icon(
              icon,
              color: locked ? p.textSecondary : color,
              size: 28,
            ),
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
            ButtonSegment<ThemeMode>(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_rounded),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_rounded),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_rounded),
            ),
          ],
          selected: <ThemeMode>{mode},
          onSelectionChanged: (Set<ThemeMode> s) => onChanged(s.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

/// Interactive row that lets the user schedule (or cancel) a daily reminder.
/// The chosen time is persisted in [SharedPreferences] under [_kPrefKey].
class _NotificationPrefRow extends StatefulWidget {
  const _NotificationPrefRow();

  @override
  State<_NotificationPrefRow> createState() => _NotificationPrefRowState();
}

class _NotificationPrefRowState extends State<_NotificationPrefRow> {
  static const String _kPrefKey = 'daily_reminder_time';

  TimeOfDay? _time;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTime();
  }

  Future<void> _loadSavedTime() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_kPrefKey);
    if (stored != null) {
      final List<String> parts = stored.split(':');
      if (parts.length == 2) {
        final int? h = int.tryParse(parts[0]);
        final int? m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          setState(() => _time = TimeOfDay(hour: h, minute: m));
        }
      }
    }
    setState(() => _loaded = true);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null || !mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, '${picked.hour}:${picked.minute}');
    await NotificationService.scheduleDailyReminder(picked);
    setState(() => _time = picked);
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
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: <Widget>[
          Icon(Icons.notifications_rounded, color: p.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Rappels quotidiens', style: t.bodyLarge)),
          Text(
            _trailingLabel,
            style: t.labelMedium?.copyWith(color: p.primary),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 18),
        ],
      ),
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

String _subtitleFromParts(String handle, int level) {
  final String lvl = 'Niveau $level';
  if (handle.isEmpty) return lvl;
  return '@$handle • $lvl';
}

String _initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final String a = parts.first.substring(0, 1);
  final String b = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (a + b).toUpperCase();
}

// ---------------------------------------------------------------------------
// Shared helper widgets
// ---------------------------------------------------------------------------

class _TappableRow extends StatelessWidget {
  const _TappableRow({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.trailingColor,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: trailingColor ?? p.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: t.bodyLarge?.copyWith(color: trailingColor),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: t.labelMedium?.copyWith(color: p.primary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 18),
        ],
      ),
    );
  }
}

class _SwitchPrefRow extends ConsumerWidget {
  const _SwitchPrefRow({
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

class _LanguagePrefRow extends StatelessWidget {
  const _LanguagePrefRow();

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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
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
      borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Bientôt',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: p.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mon compte section
// ---------------------------------------------------------------------------

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection({required this.me});

  final UserProfile me;

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  Future<void> _editDisplayName() async {
    final String current =
        ref.read(displayNameOverrideProvider) ?? widget.me.displayName;
    final TextEditingController ctrl = TextEditingController(text: current);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Modifier le nom d\'affichage'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom d\'affichage'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await ref.read(displayNameOverrideProvider.notifier).set(result);
    }
  }

  Future<void> _editHandle() async {
    final String current = ref.read(handleOverrideProvider) ?? widget.me.handle;
    final TextEditingController ctrl = TextEditingController(text: current);
    String? validationError;
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Modifier le pseudo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Pseudo',
                  prefixText: '@',
                ),
                onChanged: (String v) {
                  final bool valid = RegExp(r'^[a-z0-9_]*$').hasMatch(v);
                  setDialogState(() {
                    validationError = valid
                        ? null
                        : 'Minuscules, chiffres et _ uniquement';
                  });
                },
              ),
              if (validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    validationError!,
                    style: TextStyle(
                      color: Theme.of(ctx2).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: validationError == null
                  ? () => Navigator.of(ctx2).pop(ctrl.text)
                  : null,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await ref.read(handleOverrideProvider.notifier).set(result);
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text(
          'Cette action est irréversible. Toutes vos données seront supprimées définitivement.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (AppEnv.entraConfigured) {
        await ref.read(authControllerProvider.notifier).signOut();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Disponible bientôt')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final String? nameOverride = ref.watch(displayNameOverrideProvider);
    final String? handleOverride = ref.watch(handleOverrideProvider);
    final String displayName = nameOverride ?? widget.me.displayName;
    final String handle = handleOverride ?? widget.me.handle;

    return PrismCard(
      child: Column(
        children: <Widget>[
          _TappableRow(
            icon: Icons.person_rounded,
            label: 'Modifier le nom d\'affichage',
            trailing: displayName,
            onTap: _editDisplayName,
          ),
          Divider(color: p.border, height: 24),
          _TappableRow(
            icon: Icons.alternate_email_rounded,
            label: 'Modifier le pseudo',
            trailing: handle.isEmpty ? null : '@$handle',
            onTap: _editHandle,
          ),
          Divider(color: p.border, height: 24),
          _TappableRow(
            icon: Icons.delete_outline_rounded,
            label: 'Supprimer le compte',
            trailingColor: p.error,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Apprentissage section
// ---------------------------------------------------------------------------

class _LearningSection extends ConsumerStatefulWidget {
  const _LearningSection();

  @override
  ConsumerState<_LearningSection> createState() => _LearningSectionState();
}

class _LearningSectionState extends ConsumerState<_LearningSection> {
  Future<void> _pickGoal() async {
    DailyGoalOption current = ref.read(dailyGoalProvider);
    final DailyGoalOption? result = await showDialog<DailyGoalOption>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Objectif quotidien'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: DailyGoalOption.values
                .map(
                  (DailyGoalOption g) => RadioListTile<DailyGoalOption>(
                    value: g,
                    groupValue: current,
                    title: Text('${g.label} (${g.minutes} min / j)'),
                    onChanged: (DailyGoalOption? v) {
                      if (v != null) setDialogState(() => current = v);
                    },
                  ),
                )
                .toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(current),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await ref.read(dailyGoalProvider.notifier).set(result);
    }
  }

  Future<void> _pickLevel() async {
    KnowledgeLevel current = ref.read(knowledgeLevelProvider);
    final KnowledgeLevel? result = await showDialog<KnowledgeLevel>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Niveau Azure'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: KnowledgeLevel.values
                .map(
                  (KnowledgeLevel l) => RadioListTile<KnowledgeLevel>(
                    value: l,
                    groupValue: current,
                    title: Text(l.label),
                    onChanged: (KnowledgeLevel? v) {
                      if (v != null) setDialogState(() => current = v);
                    },
                  ),
                )
                .toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(current),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await ref.read(knowledgeLevelProvider.notifier).set(result);
    }
  }

  Future<void> _pickDomains() async {
    Set<AzureDomain> current = Set<AzureDomain>.from(ref.read(domainsProvider));
    final Set<AzureDomain>? result = await showDialog<Set<AzureDomain>>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Domaines d\'intérêt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AzureDomain.values
                  .map(
                    (AzureDomain d) => CheckboxListTile(
                      value: current.contains(d),
                      title: Text(d.label),
                      onChanged: (bool? v) {
                        setDialogState(() {
                          if (v == true) {
                            current = <AzureDomain>{...current, d};
                          } else {
                            current = current
                                .where((AzureDomain x) => x != d)
                                .toSet();
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(current),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await ref.read(domainsProvider.notifier).set(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final DailyGoalOption goal = ref.watch(dailyGoalProvider);
    final KnowledgeLevel level = ref.watch(knowledgeLevelProvider);
    final Set<AzureDomain> domains = ref.watch(domainsProvider);
    final String domainsLabel = domains.isEmpty
        ? 'Non défini'
        : '${domains.length} domaine${domains.length > 1 ? 's' : ''}';

    return PrismCard(
      child: Column(
        children: <Widget>[
          _TappableRow(
            icon: Icons.flag_rounded,
            label: 'Objectif quotidien',
            trailing: '${goal.minutes} min / j',
            onTap: _pickGoal,
          ),
          Divider(color: p.border, height: 24),
          _TappableRow(
            icon: Icons.military_tech_rounded,
            label: 'Niveau Azure',
            trailing: level.label,
            onTap: _pickLevel,
          ),
          Divider(color: p.border, height: 24),
          _TappableRow(
            icon: Icons.public_rounded,
            label: 'Domaines d\'intérêt',
            trailing: domainsLabel,
            onTap: _pickDomains,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application section
// ---------------------------------------------------------------------------

class _AppInfoSection extends StatelessWidget {
  const _AppInfoSection();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                color: p.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Version de l\'app', style: t.bodyLarge)),
              Text(
                '0.1.0 (build 1)',
                style: t.labelMedium?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          Divider(color: p.border, height: 24),
          InkWell(
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Microlingo',
            ),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.description_outlined,
                  color: p.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Licences', style: t.bodyLarge)),
                Icon(
                  Icons.chevron_right_rounded,
                  color: p.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
