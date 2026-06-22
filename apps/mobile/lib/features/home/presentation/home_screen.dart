import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/router.dart';

/// Home — the daily landing surface. Answers "what should I do today?" in one
/// glance: current readiness, daily goal progress, the next lesson to continue,
/// and concepts due for review. Skeleton uses representative sample data; wire
/// to `userRepositoryProvider` / `pathRepositoryProvider` in P1.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return AuroraBackground(
      animate: true,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: <Widget>[
            // Header ---------------------------------------------------------
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Bon retour 👋', style: t.bodyMedium?.copyWith(color: p.textSecondary)),
                      Text('Prêt pour AZ-900 ?', style: t.headlineMedium),
                    ],
                  ),
                ),
                const StreakBadge(days: 7),
                const SizedBox(width: 8),
                const XpChip(xp: 1240),
              ],
            ),
            const SizedBox(height: 24),

            // Readiness hero -------------------------------------------------
            PrismCard(
              elevation: 2,
              borderRadius: PrismRadii.cardXxl,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: <Widget>[
                  const ReadinessGauge(score: 62, previousScore: 54),
                  const SizedBox(height: 8),
                  Text('Score de préparation — AZ-900',
                      style: t.bodySmall?.copyWith(color: p.textSecondary)),
                  const SizedBox(height: 4),
                  Text('+8 cette semaine', style: t.labelMedium?.copyWith(color: p.success)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily goal -----------------------------------------------------
            _DailyGoalCard(progress: 0.6, earned: 30, goal: 50),
            const SizedBox(height: 16),

            // Continue lesson ------------------------------------------------
            Text('Continuer', style: t.titleLarge),
            const SizedBox(height: 12),
            _ContinueCard(
              unit: 'Concepts du cloud',
              lesson: 'Capex vs Opex',
              minutes: 4,
              onTap: () => context.go('${Routes.lesson}/az-900/az900-l-capex-opex'),
            ),
            const SizedBox(height: 24),

            // Review queue ---------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('À réviser', style: t.titleLarge),
                Text('3 concepts', style: t.labelMedium?.copyWith(color: p.ember)),
              ],
            ),
            const SizedBox(height: 12),
            _ReviewCard(
              concepts: const <String>[
                'Modèle de responsabilité partagée',
                'Régions et zones de disponibilité',
                'Groupes de ressources',
              ],
              onTap: () => context.go('${Routes.quiz}/az-900/az900-review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({
    required this.progress,
    required this.earned,
    required this.goal,
  });

  final double progress;
  final int earned;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      borderRadius: PrismRadii.cardXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.flag_rounded, color: p.ember, size: 20),
              const SizedBox(width: 8),
              Text('Objectif du jour', style: t.titleMedium),
              const Spacer(),
              Text('$earned / $goal XP', style: t.labelLarge?.copyWith(color: p.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          PrismProgressBar(
            value: progress,
            height: 10,
            gradient: <Color>[p.ember, p.xpGold],
            semanticLabel: 'Objectif du jour',
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.unit,
    required this.lesson,
    required this.minutes,
    required this.onTap,
  });

  final String unit;
  final String lesson;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      variant: PrismCardVariant.filled,
      accent: context.prism.primary,
      elevation: 2,
      borderRadius: PrismRadii.cardXl,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: PrismRadii.cardMd,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(unit, style: t.bodySmall?.copyWith(color: Colors.white70)),
                Text(lesson, style: t.titleMedium?.copyWith(color: Colors.white)),
                Text('$minutes min', style: t.labelSmall?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.concepts, required this.onTap});

  final List<String> concepts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: p.ember,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String c in concepts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.bolt_rounded, size: 18, color: p.ember),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c, style: t.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          PrismButton.secondary(
            label: 'Réviser maintenant (≈ 3 min)',
            icon: Icons.refresh_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
