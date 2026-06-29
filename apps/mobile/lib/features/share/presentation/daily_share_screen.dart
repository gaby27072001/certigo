import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../application/share_intent.dart';
import '../../../shared/widgets/screen_header.dart';

class DailyShareScreen extends ConsumerWidget {
  const DailyShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ShareCard> async = ref.watch(dailyShareCardProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const ScreenHeader(title: 'Partage du jour'),
            Expanded(
              child: async.when(
                data: (ShareCard card) => _DailyShareContent(card: card),
                loading: () => const _DailyShareLoading(),
                error: (Object error, StackTrace _) => PrismStatusView.error(
                  onRetry: () => ref.invalidate(dailyShareCardProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyShareContent extends ConsumerStatefulWidget {
  const _DailyShareContent({required this.card});

  final ShareCard card;

  @override
  ConsumerState<_DailyShareContent> createState() => _DailyShareContentState();
}

class _DailyShareContentState extends ConsumerState<_DailyShareContent> {
  bool _sharing = false;
  bool _copied = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareIntentProvider).shareText(
            _shareMessage(widget.card),
            subject: 'Certigo • ${widget.card.trackCode}',
          );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.card.referralCode));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final ShareCard card = widget.card;
    final AuroraMascot mascot = _mascotFrom(card.mascot);
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final String dateLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(card.generatedAt.toLocal());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: <Widget>[
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: mascot.color,
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  MascotAvatar(
                    mascot: mascot,
                    mood: card.goalMet ? MascotMood.celebrate : MascotMood.happy,
                    size: 72,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(card.headline, style: t.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          '${card.displayName}${card.formattedHandle.isEmpty ? '' : ' • ${card.formattedHandle}'}',
                          style: t.bodyMedium?.copyWith(color: p.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateLabel,
                          style: t.labelMedium?.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TagPill(
                    icon: Icons.school_rounded,
                    label: card.trackCode.isEmpty ? 'Certigo' : card.trackCode,
                    tone: mascot.color,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                card.caption,
                style: t.bodyLarge?.copyWith(
                  color: p.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Score du jour', style: t.titleMedium),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _StatPill(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Série',
                    value: '${card.streakDays} j',
                    tone: p.ember,
                  ),
                  _StatPill(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Niveau',
                    value: '${card.level}',
                    tone: p.primary,
                  ),
                  _StatPill(
                    icon: Icons.track_changes_rounded,
                    label: 'Readiness',
                    value: '${card.readinessScore}/100',
                    tone: p.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Icon(Icons.bolt_rounded, color: p.xpGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('XP du jour', style: t.titleSmall)),
                  Text(
                    '${card.dailyXp} / ${card.dailyGoalXp}',
                    style: t.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PrismProgressBar(
                value: card.goalProgress,
                height: 10,
                gradient: <Color>[
                  card.goalMet ? p.success : p.primary,
                  card.goalMet ? p.success : p.xpGold,
                ],
                semanticLabel: 'Progression quotidienne',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Code de parrainage', style: t.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Invite un ami en partageant ton code personnel.',
                style: t.bodySmall?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: PrismRadii.cardMd,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        card.referralCode,
                        style: t.titleLarge?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copier le code',
                      onPressed: _copyCode,
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
              if (_copied) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Code copie.',
                  style: t.labelMedium?.copyWith(
                    color: p.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Apercu du message', style: t.titleMedium),
              const SizedBox(height: 10),
              SelectableText(
                _shareMessage(card),
                style: t.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: PrismButton(
                label: 'Partager',
                icon: Icons.ios_share_rounded,
                loading: _sharing,
                onPressed: _sharing ? null : _share,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrismButton.secondary(
                label: 'Copier le code',
                icon: Icons.copy_rounded,
                onPressed: _copyCode,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyShareLoading extends StatelessWidget {
  const _DailyShareLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: const <Widget>[
        PrismSkeleton(height: 180),
        SizedBox(height: 16),
        PrismSkeleton(height: 168),
        SizedBox(height: 16),
        PrismSkeleton(height: 128),
        SizedBox(height: 16),
        PrismSkeleton(height: 132),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: PrismRadii.cardMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 8),
          Text(
            '$label • $value',
            style: t.labelLarge?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.icon, required this.label, required this.tone});

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.14),
        borderRadius: PrismRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: t.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

AuroraMascot _mascotFrom(String raw) => switch (raw.toLowerCase()) {
      'volt' => AuroraMascot.volt,
      'cosmo' => AuroraMascot.cosmo,
      'sentinel' => AuroraMascot.sentinel,
      'bicky' => AuroraMascot.bicky,
      'pixel' => AuroraMascot.pixel,
      'pip' => AuroraMascot.pip,
      _ => AuroraMascot.nimbus,
    };

String _shareMessage(ShareCard card) {
  final String ref = Uri.encodeComponent(card.referralCode);
  final String share = Uri.encodeComponent(card.shareId);
  return '${card.headline}\n${card.caption}\n\ncertigo://home?ref=$ref&share=$share';
}
