import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';

/// Home's AI coach shelf — "ta prochaine étape, choisie pour toi".
///
/// Watches [nextBestProvider] for the active track and renders the server-ranked
/// recommendations as a prominent hero card plus up to two secondary rows. It is
/// a *bonus* surface: it must never block Home, so it collapses to nothing while
/// loading, on error, or when the coach has no suggestion. The server already
/// localises every [Recommendation.reason], so this widget only maps each
/// [RecommendationKind] to an icon/label/accent — it never derives advice.
class CoachSection extends ConsumerWidget {
  const CoachSection({required this.trackId, super.key});

  final String trackId;

  static const int _maxSecondary = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<NextBest> async = ref.watch(nextBestProvider(trackId));

    // Hide silently unless we have at least one ranked action.
    final NextBest? next = async.asData?.value;
    if (next == null || next.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextTheme t = Theme.of(context).textTheme;
    final PrismColorScheme p = context.prism;
    final Recommendation top = next.items.first;
    final List<Recommendation> rest =
        next.items.skip(1).take(_maxSecondary).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_awesome_rounded, size: 20, color: p.primary),
            const SizedBox(width: 8),
            Text('Ton coach IA', style: t.titleLarge),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Ta prochaine étape, choisie pour toi.',
          style: t.bodySmall?.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 12),
        CoachCard(item: top, prominent: true, onTap: () => _open(context, top)),
        for (final Recommendation item in rest) ...<Widget>[
          const SizedBox(height: 10),
          CoachCard(item: item, onTap: () => _open(context, item)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _open(BuildContext context, Recommendation item) {
    if (item.hasLesson) {
      context.go('${Routes.lesson}/$trackId/${item.lessonId}');
    } else {
      context.go(Routes.path);
    }
  }
}

/// One coach recommendation, presentational and router-free so it can be widget
/// tested in isolation. [prominent] renders the hero (filled gradient) treatment
/// for the top action; the rest use the lighter tonal treatment.
class CoachCard extends StatelessWidget {
  const CoachCard({required this.item, required this.onTap, this.prominent = false, super.key});

  final Recommendation item;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final _CoachVisual v = _CoachVisual.of(item.kind, context.prism);
    return prominent ? _buildHero(context, v) : _buildRow(context, v);
  }

  Widget _buildHero(BuildContext context, _CoachVisual v) {
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      variant: PrismCardVariant.filled,
      accent: v.accent,
      elevation: 2,
      borderRadius: PrismRadii.cardXl,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: PrismRadii.cardMd,
                ),
                child: Icon(v.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      v.label.toUpperCase(),
                      style: t.labelSmall?.copyWith(color: Colors.white70, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      style: t.titleMedium?.copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
          if (item.reason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              item.reason,
              style: t.bodySmall?.copyWith(color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (item.estMinutes > 0) ...<Widget>[
                _HeroChip(icon: Icons.schedule_rounded, label: '${item.estMinutes} min'),
                const SizedBox(width: 8),
              ],
              _HeroChip(icon: _urgencyIcon, label: _urgencyLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, _CoachVisual v) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: v.accent,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: v.accent.withOpacity(0.16),
              borderRadius: PrismRadii.cardMd,
            ),
            child: Icon(v.icon, color: v.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: t.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.reason.isNotEmpty)
                  Text(
                    item.reason,
                    style: t.bodySmall?.copyWith(color: p.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.estMinutes > 0)
            Text('${item.estMinutes} min', style: t.labelSmall?.copyWith(color: p.textSecondary)),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  String get _urgencyLabel {
    if (item.forgettingRiskPct >= 60) {
      return 'Urgent';
    }
    if (item.priority >= 70) {
      return 'Prioritaire';
    }
    return 'Recommandé';
  }

  IconData get _urgencyIcon {
    if (item.forgettingRiskPct >= 60) {
      return Icons.local_fire_department_rounded;
    }
    if (item.priority >= 70) {
      return Icons.trending_up_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }
}

/// A small translucent chip used on the hero (filled) coach card.
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: PrismRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: t.labelSmall?.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Maps a [RecommendationKind] to its French label, icon and accent colour.
class _CoachVisual {
  const _CoachVisual({required this.label, required this.icon, required this.accent});

  final String label;
  final IconData icon;
  final Color accent;

  static _CoachVisual of(RecommendationKind kind, PrismColorScheme p) {
    return switch (kind) {
      RecommendationKind.practice => _CoachVisual(
          label: 'À pratiquer',
          icon: Icons.bolt_rounded,
          accent: p.ember,
        ),
      RecommendationKind.review => _CoachVisual(
          label: 'À réviser',
          icon: Icons.history_rounded,
          accent: p.primary,
        ),
      RecommendationKind.resume => _CoachVisual(
          label: 'Reprendre',
          icon: Icons.play_arrow_rounded,
          accent: p.primary,
        ),
      RecommendationKind.start => _CoachVisual(
          label: 'Démarrer',
          icon: Icons.flag_rounded,
          accent: p.success,
        ),
    };
  }
}
