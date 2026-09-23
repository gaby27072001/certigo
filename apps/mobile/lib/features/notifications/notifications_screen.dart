import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../app/providers.dart';
import '../../shared/errors/error_copy.dart';
import '../../shared/widgets/screen_header.dart';
import 'notification_destination.dart';
import 'notification_providers.dart';
import 'notification_migration.dart';
import 'notification_service.dart';
import 'notification_permissions.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? owner = ref.watch(activeTrackOwnerIdProvider);
    return _NotificationsContent(key: ValueKey<String?>(owner));
  }
}

class _NotificationsContent extends ConsumerWidget {
  const _NotificationsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<NotificationSettings> settings = ref.watch(notificationSettingsProvider);
    final AsyncValue<NotificationPlan> plan = ref.watch(notificationPlanProvider);
    final AsyncValue<void> retirement = ref.watch(retireLegacyReminderProvider);
    final LegacyNotificationChoice? legacy =
        ref.watch(legacyNotificationChoiceProvider).valueOrNull;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const ScreenHeader(title: 'Notifications'),
              Expanded(
                child: SingleChildScrollView(
                  padding: PrismSpacing.scrollBody(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const PrismCard(
                        child: Text(
                          'Le serveur conserve tes réglages et propose un plan. '
                          'Un aperçu ne programme rien : utilise « Programmer sur cet appareil » '
                          'pour confier les horaires encore futurs au système. Aucun push distant.',
                        ),
                      ),
                      if (retirement.isLoading) const LinearProgressIndicator(),
                      if (retirement.hasError)
                        _Notice(
                          title: 'Un ancien rappel peut encore sonner',
                          message: 'Son retrait sur cet appareil a échoué. Réessaie. '
                              'Si nécessaire, désactive les notifications de Certigo '
                              'dans les Réglages de ton appareil.',
                          onRetry: () => ref.invalidate(retireLegacyReminderProvider),
                        ),
                      const SizedBox(height: PrismSpacing.md),
                      Text('Réglages serveur', style: Theme.of(context).textTheme.titleLarge),
                      if (settings.isLoading) const LinearProgressIndicator(),
                      if (settings.hasError)
                        _FailureNotice(
                          error: settings.error,
                          module: 'Les réglages',
                          onRetry: () => ref.invalidate(notificationSettingsProvider),
                        ),
                      if (settings.valueOrNull case final NotificationSettings value)
                        _SettingsForm(
                          key: ObjectKey(value),
                          settings: value,
                          legacy: legacy,
                          editable: !settings.isLoading &&
                              !settings.hasError &&
                              retirement.hasValue &&
                              !retirement.hasError &&
                              !retirement.isLoading,
                        ),
                      const SizedBox(height: PrismSpacing.lg),
                      const _LocalDelivery(),
                      const SizedBox(height: PrismSpacing.lg),
                      Text('Aperçu du plan serveur', style: Theme.of(context).textTheme.titleLarge),
                      const Text(
                        'Le serveur choisit les horaires, le silence, les priorités et le quota. '
                        'Les heures ci-dessous suivent le décalage UTC enregistré, '
                        'pas nécessairement celui de cet appareil.',
                      ),
                      TextButton.icon(
                        onPressed:
                            plan.isLoading ? null : () => ref.invalidate(notificationPlanProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Actualiser le plan'),
                      ),
                      if (plan.isLoading) const LinearProgressIndicator(),
                      if (plan.hasError)
                        _FailureNotice(
                          error: plan.error,
                          module: 'Le plan',
                          onRetry: () => ref.invalidate(notificationPlanProvider),
                        ),
                      if (plan.valueOrNull case final NotificationPlan value) ...<Widget>[
                        if (plan.isLoading || plan.hasError)
                          const Text('Dernier aperçu reçu, non actualisé.'),
                        Text('Date du plan : ${value.localDate}', style: _numberStyle(context)),
                        if (value.notifications.isEmpty)
                          const PrismCard(
                            child: Text(
                                'Aucune notification retenue par le serveur pour cette journée.'),
                          ),
                        for (final PlannedNotification entry in value.notifications)
                          _PlanEntry(entry: entry),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.settings, required this.editable, this.legacy});

  final NotificationSettings settings;
  final bool editable;
  final LegacyNotificationChoice? legacy;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late NotificationSettings _draft = widget.legacy?.applyTo(widget.settings) ?? widget.settings;
  bool _hourConfirmed = false;
  bool _saving = false;
  bool _saved = false;
  Failure? _failure;

  void _change(NotificationSettings next) => setState(() {
        _draft = next;
        _saved = false;
      });

  Future<void> _save() async {
    if (_saving || !widget.editable || ref.read(notificationMutationProvider)) return;
    final StateController<bool> mutation = ref.read(notificationMutationProvider.notifier);
    mutation.state = true;
    try {
      await _saveSettings();
    } finally {
      if (mounted) mutation.state = false;
    }
  }

  Future<void> _saveSettings() async {
    final String? owner = ref.read(activeTrackOwnerIdProvider);
    if (owner == null) return;
    setState(() {
      _saving = true;
      _failure = null;
      _saved = false;
    });
    try {
      if (!_draft.enabled) await widget.legacy?.disableLocally();
      if (widget.legacy == null || !_draft.enabled) {
        await NotificationService.cancelDailyReminder();
      }
    } on Object catch (error, stack) {
      FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack, library: 'certigo.notifications'));
      if (mounted) {
        setState(() {
          _failure = const CacheFailure();
          _saving = false;
        });
      }
      return;
    }
    if (!mounted || owner != ref.read(activeTrackOwnerIdProvider)) return;
    final bool preserveLegacyHour =
        (widget.legacy?.needsHourConfirmation ?? false) && !_hourConfirmed;
    final NotificationSettings request =
        preserveLegacyHour ? _draft.copyWith(preferredHour: widget.settings.preferredHour) : _draft;
    final Result<NotificationSettings> result =
        await ref.read(notificationRepositoryProvider).updateSettings(request);
    if (!mounted || owner != ref.read(activeTrackOwnerIdProvider)) return;
    if (result.isSuccess) {
      try {
        if (!preserveLegacyHour) await widget.legacy?.complete();
        await NotificationService.cancelDailyReminder();
      } on Object catch (error, stack) {
        FlutterError.reportError(
            FlutterErrorDetails(exception: error, stack: stack, library: 'certigo.notifications'));
        if (mounted) {
          setState(() {
            _failure = const CacheFailure();
            _saving = false;
          });
        }
        return;
      }
      if (!mounted || owner != ref.read(activeTrackOwnerIdProvider)) return;
      if (widget.legacy != null) ref.invalidate(legacyNotificationChoiceProvider);
    }
    result.when(
      success: (NotificationSettings saved) {
        setState(() {
          _draft = saved;
          _saved = true;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réglages enregistrés sur le serveur.')),
        );
        ref.invalidate(notificationSettingsProvider);
        ref.invalidate(notificationPlanProvider);
      },
      failure: (Failure failure) => setState(() {
        _failure = failure;
        _saving = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editable = widget.editable && !ref.watch(notificationMutationProvider);
    return PrismCard(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!widget.editable)
              const Text(
                  'Derniers réglages reçus. Modification indisponible pendant la vérification.'),
            if (widget.legacy case final LegacyNotificationChoice legacy) ...<Widget>[
              Text(legacy.enabled == false
                  ? 'Ton ancien rappel reste désactivé tant que la migration n’est pas terminée.'
                  : 'Ton ancien rappel de ${legacy.timeLabel} reste conservé avant migration.'),
              if (legacy.needsHourConfirmation)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Remplacer ${legacy.timeLabel} par ${_draft.preferredHour} h'),
                  subtitle: const Text('Le serveur accepte uniquement les heures entières. '
                      'Aucun arrondi sans ton accord.'),
                  value: _hourConfirmed,
                  onChanged:
                      editable ? (bool? v) => setState(() => _hourConfirmed = v == true) : null,
                ),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activer le plan serveur'),
              subtitle: const Text('Ne déclenche aucun envoi sur cet appareil.'),
              value: _draft.enabled,
              onChanged: editable ? (bool value) => _change(_draft.copyWith(enabled: value)) : null,
            ),
            _HourField(
              label: 'Début du silence',
              value: _draft.quietHoursStart,
              onChanged:
                  editable ? (int value) => _change(_draft.copyWith(quietHoursStart: value)) : null,
            ),
            _HourField(
              label: 'Fin du silence',
              value: _draft.quietHoursEnd,
              onChanged:
                  editable ? (int value) => _change(_draft.copyWith(quietHoursEnd: value)) : null,
            ),
            _HourField(
              label: 'Heure préférée',
              value: _draft.preferredHour,
              onChanged:
                  editable ? (int value) => _change(_draft.copyWith(preferredHour: value)) : null,
            ),
            const Text('Le serveur peut adapter cette heure à ton activité.'),
            _NumberField(
              label: 'Maximum par jour',
              value: _draft.maxPerDay,
              min: 0,
              max: 10,
              onChanged:
                  editable ? (int value) => _change(_draft.copyWith(maxPerDay: value)) : null,
            ),
            _NumberField(
              label: 'Décalage UTC en minutes',
              value: _draft.utcOffsetMinutes,
              min: -720,
              max: 840,
              onChanged: editable
                  ? (int value) => _change(_draft.copyWith(utcOffsetMinutes: value))
                  : null,
            ),
            TextButton(
              onPressed: editable
                  ? () => _change(_draft.copyWith(
                        utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
                      ))
                  : null,
              child: const Text('Utiliser le décalage actuel de cet appareil'),
            ),
            const Text('À mettre à jour après un voyage ou un changement d’heure.'),
            for (final (String, bool, NotificationSettings Function(bool)) option
                in <(String, bool, NotificationSettings Function(bool))>[
              (
                'Alertes de série',
                _draft.streakAlerts,
                (bool v) => _draft.copyWith(streakAlerts: v)
              ),
              (
                'Alertes de quêtes',
                _draft.questAlerts,
                (bool v) => _draft.copyWith(questAlerts: v)
              ),
              (
                'Alertes de ligue',
                _draft.leagueAlerts,
                (bool v) => _draft.copyWith(leagueAlerts: v)
              ),
            ])
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(option.$1),
                value: option.$2,
                onChanged: editable ? (bool value) => _change(option.$3(value)) : null,
              ),
            if (_failure != null)
              _FailureNotice(
                  error: _failure, module: 'La sauvegarde', onRetry: editable ? _save : null),
            if (_saved)
              Semantics(
                liveRegion: true,
                child: const Text('Réglages enregistrés sur le serveur. Aucun envoi programmé.'),
              ),
            FilledButton(
              onPressed: editable &&
                      (!(widget.legacy?.needsHourConfirmation ?? false) ||
                          _hourConfirmed ||
                          !_draft.enabled)
                  ? _save
                  : null,
              child: Text(_saving ? 'Enregistrement…' : 'Enregistrer les réglages'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalDelivery extends ConsumerStatefulWidget {
  const _LocalDelivery();

  @override
  ConsumerState<_LocalDelivery> createState() => _LocalDeliveryState();
}

class _LocalDeliveryState extends ConsumerState<_LocalDelivery> {
  bool _busy = false;
  bool _permissionDenied = false;
  String? _message;

  Future<void> _activate() async {
    if (_busy || ref.read(notificationMutationProvider)) return;
    final StateController<bool> mutation = ref.read(notificationMutationProvider.notifier);
    mutation.state = true;
    try {
      await _activatePlan();
    } finally {
      if (mounted) mutation.state = false;
    }
  }

  Future<void> _activatePlan() async {
    final String? owner = ref.read(activeTrackOwnerIdProvider);
    if (_busy || owner == null) return;
    setState(() {
      _busy = true;
      _permissionDenied = false;
      _message = null;
    });
    try {
      final NotificationSettings settings = await ref.refresh(notificationSettingsProvider.future);
      final LegacyNotificationChoice? legacy = await LegacyNotificationChoice.load(owner);
      if (!mounted || owner != ref.read(activeTrackOwnerIdProvider)) return;
      if (legacy != null) {
        setState(
            () => _message = 'Confirme et enregistre d’abord la migration de ton ancien rappel.');
        return;
      }
      final NotificationPlan plan = await ref.refresh(notificationPlanProvider.future);
      if (!mounted || owner != ref.read(activeTrackOwnerIdProvider)) return;
      final int? count = await NotificationService.scheduleServerPlan(settings, plan);
      if (!mounted || owner != ref.read(activeTrackOwnerIdProvider)) return;
      setState(() {
        _permissionDenied = count == null;
        _message = count == null
            ? 'Autorisation absente ou notifications non prises en charge. '
                'Sur iPhone ou Android, autorise Certigo dans les Réglages puis réessaie.'
            : count == 0
                ? 'Aucun rappel local programmé : plan désactivé, horaires passés ou contexte modifié.'
                : null;
      });
    } on Object catch (error, stack) {
      FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack, library: 'certigo.notifications'));
      if (mounted) {
        setState(() {
          _message = error is Failure
              ? describeFailure(error).message
              : 'La programmation locale a échoué. Réessaie avec un plan actualisé. '
                  'En cas de doute, désactive Certigo dans les Réglages de notifications.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    try {
      await NotificationPermissions.openSettings();
    } on Object catch (error, stack) {
      FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack, library: 'certigo.notifications'));
      if (mounted) {
        setState(() =>
            _message = 'Impossible d’ouvrir les Réglages. Ouvre les réglages de ton appareil, '
                'puis Notifications et Certigo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Sur cet appareil', style: Theme.of(context).textTheme.titleLarge),
          const Text('Seuls les réglages enregistrés sont utilisés. Les rappels sont ponctuels, '
              'sans renouvellement quotidien. Un retour dans l’app ou un changement de compte '
              'annule ce lot : programme alors un nouvel aperçu. '
              'Le système peut retarder ou bloquer leur affichage.'),
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.scheduledCount,
            builder: (_, int count, __) => Semantics(
                liveRegion: true,
                child: Text(
                  count == 0
                      ? 'Aucun lot local actif.'
                      : '$count rappel(s) confié(s) au système pour ce plan ; certains horaires '
                          'peuvent être déjà passés.',
                  style: _numberStyle(context),
                )),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: NotificationService.cancellationFailed,
            builder: (_, bool failed, __) => failed
                ? const Text('Une annulation a échoué : des rappels peuvent encore sonner. '
                    'Réessaie ou désactive Certigo dans les Réglages de ton appareil.')
                : const SizedBox.shrink(),
          ),
          if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
          if (_permissionDenied)
            TextButton(onPressed: _openSettings, child: const Text('Ouvrir les Réglages')),
          FilledButton(
            onPressed: ref.watch(notificationMutationProvider) ? null : _activate,
            child: Text(_busy ? 'Vérification…' : 'Programmer sur cet appareil'),
          ),
        ],
      ),
    );
  }
}

class _HourField extends StatelessWidget {
  const _HourField({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: PrismSpacing.xs),
        child: DropdownButtonFormField<int>(
          key: ValueKey<String>('$label:$value'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: List<DropdownMenuItem<int>>.generate(
            24,
            (int hour) => DropdownMenuItem<int>(
              value: hour,
              child: Text('${hour.toString().padLeft(2, '0')} h', style: _numberStyle(context)),
            ),
          ),
          onChanged: onChanged == null
              ? null
              : (int? next) {
                  if (next != null) onChanged!(next);
                },
        ),
      );
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: PrismSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.label),
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Diminuer : ${widget.label}',
                  onPressed: widget.onChanged != null && widget.value > widget.min
                      ? () => widget.onChanged!(widget.value - 1)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: widget.label,
                    child: Text('${widget.value}',
                        textAlign: TextAlign.center, style: _numberStyle(context)),
                  ),
                ),
                IconButton(
                  tooltip: 'Augmenter : ${widget.label}',
                  onPressed: widget.onChanged != null && widget.value < widget.max
                      ? () => widget.onChanged!(widget.value + 1)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ),
      );
}

TextStyle? _numberStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge?.copyWith(fontFeatures: const <FontFeature>[
      FontFeature.tabularFigures(),
    ]);

class _PlanEntry extends StatelessWidget {
  const _PlanEntry({required this.entry});
  final PlannedNotification entry;

  @override
  Widget build(BuildContext context) {
    final String? destination = notificationDestination(entry.deeplink);
    return Padding(
      padding: const EdgeInsets.only(top: PrismSpacing.sm),
      child: PrismCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
            Text(entry.body),
            Text('Catégorie : ${_kindLabel(entry.kind)}'),
            Text('Priorité : ${_priorityLabel(entry.priority)} · Mascotte : ${entry.mascot}'),
            Text('Heure du plan : ${entry.localHour.toString().padLeft(2, '0')} h',
                style: _numberStyle(context)),
            Text('Instant UTC : ${entry.scheduledUtc.toIso8601String()}',
                style: _numberStyle(context)),
            const Text('Aperçu, pas un rappel programmé sur cet appareil.'),
            if (destination != null)
              TextButton(
                onPressed: () => context.go(destination),
                child: Text(entry.deeplink == 'certigo://lesson/next'
                    ? 'Choisir ma prochaine leçon sur l’accueil'
                    : 'Ouvrir dans Certigo'),
              )
            else
              const Text('Destination non prise en charge par cette version.'),
          ],
        ),
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
        'StreakDanger' => 'Série',
        'Comeback' => 'Retour',
        'DailyReminder' => 'Apprentissage',
        'QuestNudge' => 'Quêtes',
        'LeagueNudge' => 'Ligue',
        'Milestone' => 'Jalon',
        _ => 'Autre catégorie serveur',
      };

  String _priorityLabel(String priority) => switch (priority) {
        'Low' => 'Faible',
        'Normal' => 'Normale',
        'High' => 'Haute',
        'Critical' => 'Critique',
        _ => 'Non reconnue',
      };
}

class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.error, required this.module, required this.onRetry});
  final Object? error;
  final String module;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ErrorCopy copy = describeFailure(error);
    final bool missing = copy.kind == ErrorKind.notFound;
    return _Notice(
      title: missing ? '$module : indisponible sur ce serveur' : copy.title,
      message: missing
          ? 'Le reste de Certigo reste accessible. Réessaie après la mise à jour du service.'
          : copy.message,
      onRetry: missing || copy.retryResolves ? onRetry : null,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.message, required this.onRetry});
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PrismSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(message),
              if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
}
