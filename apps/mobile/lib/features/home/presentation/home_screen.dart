import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/router.dart';
import '../application/home_controller.dart';
import 'coach_section.dart';

/// Home — the daily landing surface. Answers "what should I do today?" in one
/// glance: current readiness, daily goal progress, the next lesson to continue,
/// and the weakest domain to reinforce. Driven by [homeDataProvider] (real
/// profile + path from the API), with skeleton loading and a retry error state.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeData> async = ref.watch(homeDataProvider);

    return AuroraBackground(
      animate: true,
      child: SafeArea(
        bottom: false,
        child: async.when(
          data: (HomeData data) => _HomeContent(data: data),
          loading: () => const _HomeLoading(),
          error: (Object error, StackTrace _) => PrismStatusView.error(
            onRetry: () => ref.invalidate(homeDataProvider),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final UserProfile me = data.profile;
    final LearningPath path = data.path;
    final PathLesson? next = data.nextLesson;
    final PathUnit? nextUnit = data.nextUnit;
    final DomainProgress? weak = data.weakestDomain;
    final String firstName = me.displayName.split(' ').first;
    final int previous = (path.readinessScore - path.readinessTrend7d).clamp(0, 100);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: <Widget>[
        // Greeting -------------------------------------------------------
        Text(
          'Bon retour, $firstName 👋',
          style: t.bodyMedium?.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          path.exam.isEmpty ? 'Prêt à progresser ?' : 'Cap sur ${path.exam}',
          style: t.headlineMedium,
        ),
        const SizedBox(height: 16),

        // Stats ----------------------------------------------------------
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            StreakBadge(days: me.streakDays),
            GemCounter(gems: me.gems),
            XpChip(xp: me.xp),
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
              ReadinessGauge(score: path.readinessScore, previousScore: previous),
              const SizedBox(height: 8),
              Text(
                path.exam.isEmpty ? 'Score de préparation' : 'Score de préparation — ${path.exam}',
                style: t.bodySmall?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 4),
              _TrendLabel(trend: path.readinessTrend7d),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Daily goal -----------------------------------------------------
        _DailyGoalCard(
          progress: me.dailyProgress,
          earned: me.dailyXpEarned,
          goal: me.dailyGoalXp,
        ),
        const SizedBox(height: 16),

        // AI coach — server-ranked "next best action" shelf. Self-hiding:
        // collapses to nothing while loading, on error, or when empty, so it
        // never blocks the rest of Home.
        CoachSection(trackId: path.trackId),

        // Continue lesson ------------------------------------------------
        Text('Continuer', style: t.titleLarge),
        const SizedBox(height: 12),
        if (next != null)
          _ContinueCard(
            unit: nextUnit?.title ?? path.trackName,
            lesson: next.title,
            minutes: next.estMinutes,
            onTap: () => context.go('${Routes.lesson}/${path.trackId}/${next.id}'),
          )
        else
          _AllCaughtUpCard(onTap: () => context.go(Routes.path)),
        const SizedBox(height: 24),

        // Weakest domain -------------------------------------------------
        if (weak != null) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('À renforcer', style: t.titleLarge),
              Text(
                '${weak.score}/100',
                style: t.labelMedium?.copyWith(color: p.ember),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WeakDomainCard(domain: weak, onTap: () => context.go(Routes.path)),
        ],
      ],
    );
  }
}

class _TrendLabel extends StatelessWidget {
  const _TrendLabel({required this.trend});

  final int trend;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    if (trend == 0) {
      return Text(
        'Stable cette semaine',
        style: t.labelMedium?.copyWith(color: p.textSecondary),
      );
    }
    final bool up = trend > 0;
    return Text(
      '${up ? '+' : ''}$trend cette semaine',
      style: t.labelMedium?.copyWith(color: up ? p.success : p.warning),
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

class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: p.success,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(Icons.celebration_rounded, color: p.success, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Tout est à jour !', style: t.titleMedium),
                Text(
                  'Explore ton parcours pour aller plus loin.',
                  style: t.bodySmall?.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _WeakDomainCard extends StatelessWidget {
  const _WeakDomainCard({required this.domain, required this.onTap});

  final DomainProgress domain;
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
          Row(
            children: <Widget>[
              Icon(Icons.bolt_rounded, size: 18, color: p.ember),
              const SizedBox(width: 10),
              Expanded(child: Text(domain.name, style: t.bodyLarge)),
            ],
          ),
          const SizedBox(height: 10),
          PrismProgressBar(
            value: (domain.score / 100).clamp(0, 1).toDouble(),
            height: 8,
            gradient: <Color>[p.ember, p.xpGold],
            semanticLabel: domain.name,
          ),
          const SizedBox(height: 12),
          PrismButton.secondary(
            label: 'Renforcer ce domaine',
            icon: Icons.trending_up_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: const <Widget>[
        PrismSkeleton(width: 150, height: 14),
        SizedBox(height: 12),
        PrismSkeleton(width: 200, height: 28),
        SizedBox(height: 24),
        PrismSkeleton(height: 220),
        SizedBox(height: 16),
        PrismSkeleton(height: 72),
        SizedBox(height: 16),
        PrismSkeleton(height: 96),
      ],
    );
  }
}
