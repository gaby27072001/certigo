import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';

/// Achievements — the learner's trophy cabinet. Read-only board fed by
/// `achievementBoardProvider`. We celebrate what is unlocked, and for the rest
/// we show honest, motivating progress toward each threshold rather than a bare
/// lock. Presented above the shell, so it carries its own back affordance.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AchievementBoard> async = ref.watch(achievementBoardProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _ScreenHeader(title: 'Succès'),
            Expanded(
              child: async.when(
                data: (AchievementBoard board) => _AchievementsContent(board: board),
                loading: () => const _AchievementsLoading(),
                error: (Object error, StackTrace _) => PrismStatusView.error(
                  onRetry: () => ref.invalidate(achievementBoardProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsContent extends StatelessWidget {
  const _AchievementsContent({required this.board});

  final AchievementBoard board;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final double overall =
        board.total > 0 ? (board.unlocked / board.total).clamp(0.0, 1.0) : 0.0;

    if (board.achievements.isEmpty) {
      return const PrismStatusView(
        icon: Icons.workspace_premium_rounded,
        title: 'Aucun succès pour le moment',
        message: 'Continue d\'apprendre : tes premiers trophées arrivent vite.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: <Widget>[
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: p.xpGold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.emoji_events_rounded, color: p.xpGold, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Trophées débloqués', style: t.titleMedium),
                  ),
                  Text(
                    '${board.unlocked}/${board.total}',
                    style: t.titleLarge?.copyWith(
                      color: p.xpGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PrismProgressBar(
                value: overall,
                semanticLabel: 'Progression globale des succès',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final Achievement a in board.achievements) ...<Widget>[
          _AchievementCard(achievement: a),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool unlocked = achievement.unlocked;
    final Color tierColor = _tierColor(p, achievement.tier);
    final double value = achievement.threshold > 0
        ? (achievement.progress / achievement.threshold).clamp(0.0, 1.0)
        : (unlocked ? 1.0 : 0.0);

    return PrismCard(
      variant: unlocked ? PrismCardVariant.tonal : PrismCardVariant.surface,
      accent: unlocked ? tierColor : null,
      elevation: unlocked ? 2 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(unlocked ? 0.22 : 0.12),
                  borderRadius: PrismRadii.cardMd,
                ),
                child: Icon(
                  unlocked ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
                  color: unlocked ? tierColor : p.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      achievement.name,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achievement.description,
                      style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TierTag(tier: achievement.tier, color: tierColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: PrismProgressBar(
                  value: value,
                  gradient: unlocked ? <Color>[tierColor, tierColor] : null,
                  semanticLabel: 'Progression du succès',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${achievement.progress}/${achievement.threshold}',
                style: t.labelMedium?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          if (achievement.rewardGems > 0) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(Icons.diamond_rounded, size: 16, color: p.info),
                const SizedBox(width: 6),
                Text(
                  unlocked
                      ? 'Récompense obtenue : ${achievement.rewardGems} gemmes'
                      : 'Récompense : ${achievement.rewardGems} gemmes',
                  style: t.labelMedium?.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TierTag extends StatelessWidget {
  const _TierTag({required this.tier, required this.color});

  final String tier;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: PrismRadii.pillAll,
      ),
      child: Text(
        _tierLabel(tier),
        style: t.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AchievementsLoading extends StatelessWidget {
  const _AchievementsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: const <Widget>[
        PrismSkeleton(height: 88),
        SizedBox(height: 16),
        PrismSkeleton(height: 120),
        SizedBox(height: 12),
        PrismSkeleton(height: 120),
        SizedBox(height: 12),
        PrismSkeleton(height: 120),
      ],
    );
  }
}

/// Shared back-bar for above-shell feature screens.
class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(Routes.home);
              }
            },
          ),
          const SizedBox(width: 4),
          Text(title, style: t.headlineSmall),
        ],
      ),
    );
  }
}

String _tierLabel(String tier) {
  return switch (tier) {
    'bronze' => 'Bronze',
    'silver' => 'Argent',
    'gold' => 'Or',
    'platinum' => 'Platine',
    'diamond' => 'Diamant',
    _ => tier,
  };
}

Color _tierColor(PrismColorScheme p, String tier) {
  return switch (tier) {
    'bronze' => p.ember,
    'silver' => const Color(0xFFB8C2D9),
    'gold' => p.xpGold,
    'platinum' => p.info,
    'diamond' => p.primary,
    _ => p.textSecondary,
  };
}
