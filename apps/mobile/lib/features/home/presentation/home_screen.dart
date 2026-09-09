import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
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
          error: (Object error, StackTrace _) => error is MissingActiveTrackException
              ? PrismStatusView(
                  icon: Icons.school_outlined,
                  title: 'Aucune certification sélectionnée',
                  message: 'Choisis un parcours publié pour afficher ton accueil.',
                  actionLabel: 'Voir la bibliothèque',
                  onAction: () => context.go(Routes.library),
                )
              : PrismStatusView.error(onRetry: () => ref.invalidate(homeDataProvider)),
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
    final DomainProgress? weak = data.weakestDomain;
    final String firstName = me.displayName.split(' ').first;
    final int previous = (path.readinessScore - path.readinessTrend7d).clamp(0, 100);

    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
      children: <Widget>[
        // Resource bar — streak / gems / XP, the at-a-glance economy, pinned at
        // the top like a learning app's status row.
        Row(
          children: <Widget>[
            StreakBadge(days: me.streakDays, active: me.dailyProgress >= 1),
            const SizedBox(width: 8),
            GemCounter(gems: me.gems),
            const Spacer(),
            XpChip(xp: me.xp),
          ],
        ),
        const SizedBox(height: 18),

        // Greeting — the guide welcomes you back in a speech bubble.
        _HomeGreeting(
          firstName: firstName,
          subtitle: path.exam.isEmpty ? 'Prêt à progresser ?' : 'Cap sur ${path.exam}',
        ),
        const SizedBox(height: 22),

        // Readiness hero -------------------------------------------------
        PrismCard(
          elevation: 2,
          borderRadius: PrismRadii.cardXxl,
          padding: const EdgeInsets.symmetric(vertical: PrismSpacing.lg),
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
        _DailyGoalCard(progress: me.dailyProgress, earned: me.dailyXpEarned, goal: me.dailyGoalXp),
        const SizedBox(height: 16),
        _DailyShareEntryCard(
          goalMet: me.dailyGoalXp > 0 && me.dailyXpEarned >= me.dailyGoalXp,
          trackCode: path.exam,
          onTap: () => context.push(Routes.dailyShare),
        ),
        const SizedBox(height: 16),

        // AI coach — server-ranked "next best action" shelf. Self-hiding:
        // collapses to nothing while loading, on error, or when empty, so it
        // never blocks the rest of Home.
        CoachSection(trackId: path.trackId),

        // Current lesson indicator (non-interactive — action is in Parcours).
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Text('📍', style: TextStyle(fontSize: 22)),
          title: Text(next?.title ?? 'Aucune leçon en cours', style: t.bodyLarge),
        ),
        const SizedBox(height: 24),

        // Explorer — secondary destinations beyond the daily path.
        const PrismSectionHeader(
          title: 'Explorer',
          subtitle: 'Choisis ton prochain objectif',
          icon: Icons.explore_rounded,
        ),
        const SizedBox(height: 12),
        const _ExploreSection(),
        const SizedBox(height: 24),

        // Weakest domain -------------------------------------------------
        if (weak != null) ...<Widget>[
          PrismSectionHeader(
            title: 'À renforcer',
            subtitle: 'Un effort ciblé fait vite progresser',
            icon: Icons.bolt_rounded,
            trailing: Text('${weak.score}/100', style: t.labelMedium?.copyWith(color: p.ember)),
          ),
          const SizedBox(height: 12),
          _WeakDomainCard(domain: weak, onTap: () => context.go(Routes.path)),
        ],
      ],
    );
  }
}

class _HomeGreeting extends StatefulWidget {
  const _HomeGreeting({required this.firstName, required this.subtitle});

  final String firstName;
  final String subtitle;

  @override
  State<_HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends State<_HomeGreeting> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final PrismColorScheme p = context.prism;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Duration d = reduceMotion ? Duration.zero : PrismMotion.base;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismReveal(
          visible: _visible,
          from: const Offset(-0.08, 0),
          duration: d,
          child: const MascotAvatar(
            mascot: AuroraMascot.nimbus,
            mood: MascotMood.happy,
            size: 64,
            showBadge: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrismReveal(
            visible: _visible,
            from: const Offset(0.08, 0),
            duration: d,
            child: SpeechBubble(
              tail: SpeechTail.left,
              tailAlignment: 0.34,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Bon retour, ${widget.firstName} 👋',
                    style: t.bodyMedium?.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(widget.subtitle, style: t.titleLarge),
                ],
              ),
            ),
          ),
        ),
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
      return Text('Stable cette semaine', style: t.labelMedium?.copyWith(color: p.textSecondary));
    }
    final bool up = trend > 0;
    return Text(
      '${up ? '+' : ''}$trend cette semaine',
      style: t.labelMedium?.copyWith(color: up ? p.success : p.warning),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.progress, required this.earned, required this.goal});

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

class _DailyShareEntryCard extends StatelessWidget {
  const _DailyShareEntryCard({required this.goalMet, required this.trackCode, required this.onTap});

  final bool goalMet;
  final String trackCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color tone = goalMet ? p.success : p.primary;

    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: tone,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.16),
              borderRadius: PrismRadii.cardMd,
            ),
            child: Icon(Icons.share_rounded, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Partage du jour', style: t.titleMedium),
                const SizedBox(height: 2),
                Text(
                  goalMet
                      ? 'Ton objectif est atteint — partage ta progression ${trackCode.isEmpty ? '' : trackCode}.'
                      : 'Transforme tes progrès du jour en carte de partage prête a envoyer.',
                  style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary),
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
      padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
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

/// "Explore" shelf on Home — a 2-column grid of secondary destinations
/// (achievements, seasons, quests, shop, friends, mock exam) presented above
/// the shell so they never compete with the bottom-nav primary tabs.
class _ExploreSection extends StatelessWidget {
  const _ExploreSection();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final List<_ExploreItem> items = <_ExploreItem>[
      _ExploreItem(
        icon: Icons.emoji_events_rounded,
        label: 'Succès',
        tone: p.xpGold,
        route: Routes.achievements,
      ),
      _ExploreItem(
        icon: Icons.calendar_month_rounded,
        label: 'Saisons',
        tone: p.primary,
        route: Routes.seasons,
      ),
      _ExploreItem(icon: Icons.flag_rounded, label: 'Quêtes', tone: p.ember, route: Routes.quests),
      _ExploreItem(
        icon: Icons.storefront_rounded,
        label: 'Boutique',
        tone: p.success,
        route: Routes.shop,
      ),
      _ExploreItem(icon: Icons.group_rounded, label: 'Amis', tone: p.info, route: Routes.friends),
      _ExploreItem(
        icon: Icons.workspace_premium_rounded,
        label: 'Examen blanc',
        tone: p.warning,
        route: Routes.exam,
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 12;
        final double tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final _ExploreItem item in items)
              SizedBox(
                width: tileWidth,
                child: _ExploreCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _ExploreItem {
  const _ExploreItem({
    required this.icon,
    required this.label,
    required this.tone,
    required this.route,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final String route;
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.item});

  final _ExploreItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final PrismColorScheme p = context.prism;
    return GestureDetector(
      // Les explorations s'ouvrent au-dessus du shell : on empile pour que le
      // geste iOS de retour par balayage ramène à Home. Exception : l'examen
      // blanc reste en `go` — sa progression n'a pas de sauvegarde par étape,
      // et un geste retour perdrait l'attempt en cours (à revoir séparément).
      onTap: () => item.route == Routes.exam ? context.go(item.route) : context.push(item.route),
      child: PrismCard(
        borderRadius: PrismRadii.cardLg,
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.md,
          vertical: PrismSpacing.cardInset,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.tone.withOpacity(0.16),
                borderRadius: PrismRadii.cardMd,
              ),
              child: Icon(item.icon, color: item.tone, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: t.titleSmall?.copyWith(color: p.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
