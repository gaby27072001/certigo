import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../streak/presentation/streak_copy.dart';
import '../../streak/presentation/streak_repair_banner.dart';
import '../application/home_controller.dart';
import 'coach_section.dart';

/// Home — the daily landing surface. Answers "what should I do today?" in one
/// glance: current readiness, daily goal progress, the next lesson to continue,
/// and the weakest domain to reinforce.
///
/// Home renders in three independent bands so that no single failure can empty
/// the landing surface:
///
/// * **You** — streak, gems, XP, greeting and the daily goal, from [meProvider].
///   The streak badge opens « Ma série »; a repair prompt appears beside it only
///   while the server offers one (`StreakRepairBanner`, self-hiding).
/// * **Your certification** — readiness, coach, next lesson and weakest domain,
///   from [homePathProvider]. Having selected no track yet is data, not an
///   error, so it degrades to an invitation instead of a takeover.
/// * **Explorer** — static, and load-bearing: of the six destinations it
///   lists, five (Saisons, Quêtes, Boutique, Amis, Examen blanc) have no other
///   entry point anywhere in the app. Succès is also reachable from Profil.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile> profile = ref.watch(meProvider);
    final AsyncValue<LearningPath?> pathState = ref.watch(homePathProvider);
    final LearningPath? path = pathState.valueOrNull;

    return AuroraBackground(
      animate: true,
      child: SafeArea(
        bottom: false,
        // The bottom edge fades while content remains below it. Home is the one
        // surface where that matters most: the Explorer shelf sits at the fold,
        // and five of its six destinations exist nowhere else in the app. A
        // page that simply stops at the screen edge does not say "keep going".
        //
        // The scrim is the aurora's own base colour, not a flat panel: the
        // gradient is subtle enough at this depth that the two agree, and a
        // mismatched scrim would read as a band.
        child: PrismScrollEdge(
          color: context.prism.background,
          child: ListView(
            padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
            children: <Widget>[
              // ── You ───────────────────────────────────────────────────────
              _ResourceBar(profile: profile),
              const SizedBox(height: 18),
              _HomeGreeting(
                firstName: profile.valueOrNull?.displayName.split(' ').first,
                subtitle: _greetingSubtitle(path),
              ),
              const SizedBox(height: 22),

              // ── Your streak — only while the server offers a repair ───────
              const StreakRepairBanner(),

              // ── Your certification ────────────────────────────────────────
              _TrackBand(
                state: pathState,
                onRetry: () => ref.invalidate(homePathProvider),
              ),
              const SizedBox(height: 16),

              // ── Your day ──────────────────────────────────────────────────
              _DailyBand(
                profile: profile,
                trackCode: path?.exam ?? '',
                onRetry: () => ref.invalidate(meProvider),
              ),

              if (path != null) ...<Widget>[
                const SizedBox(height: 16),
                // AI coach — server-ranked "next best action" shelf. Self-hiding:
                // collapses to nothing while loading, on error, or when empty, so
                // it never blocks the rest of Home.
                CoachSection(trackId: path.trackId),

                // Current lesson indicator (non-interactive — action is in Parcours).
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('📍', style: TextStyle(fontSize: 22)),
                  title: Text(
                    path.nextLesson?.title ?? HomeLabels.noLessonInProgress,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ── Explorer — secondary destinations beyond the daily path ────
              const PrismSectionHeader(
                title: 'Explorer',
                subtitle: 'Choisis ton prochain objectif',
                icon: Icons.explore_rounded,
              ),
              const SizedBox(height: 12),
              const _ExploreSection(),

              // ── Weakest domain ────────────────────────────────────────────
              if (path?.weakestDomain case final DomainProgress weak) ...<Widget>[
                const SizedBox(height: 24),
                PrismSectionHeader(
                  title: 'À renforcer',
                  subtitle: 'Un effort ciblé fait vite progresser',
                  icon: Icons.bolt_rounded,
                  trailing: Text(
                    '${weak.score}/100',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: context.prism.ember),
                  ),
                ),
                const SizedBox(height: 12),
                _WeakDomainCard(domain: weak, onTap: () => context.go(Routes.path)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _greetingSubtitle(LearningPath? path) {
    if (path == null) {
      return HomeLabels.noTrackGreeting;
    }
    return path.exam.isEmpty ? 'Prêt à progresser ?' : 'Cap sur ${path.exam}';
  }
}

/// Copy that tests assert on. Naming it keeps a wording change from silently
/// turning a widget test red in an unrelated branch.
abstract final class HomeLabels {
  static const String noTrackTitle = 'Aucune certification sélectionnée';
  static const String noTrackMessage = 'Choisis un parcours publié pour afficher ton accueil.';
  static const String noTrackAction = 'Voir la bibliothèque';
  static const String noTrackGreeting = 'Choisis ta certification pour commencer';
  static const String noLessonInProgress = 'Aucune leçon en cours';
  static const String profileUnavailable = 'Tes chiffres du jour sont indisponibles.';
  static const String pathUnavailable = 'Impossible de charger ton parcours.';
}

/// The learner's economy row — streak, gems, XP. Skeletons while loading, and
/// silently absent if the profile fails: the retry lives once, in [_DailyBand].
class _ResourceBar extends StatelessWidget {
  const _ResourceBar({required this.profile});

  final AsyncValue<UserProfile> profile;

  @override
  Widget build(BuildContext context) {
    final UserProfile? me = profile.valueOrNull;
    if (me == null) {
      return const Row(
        children: <Widget>[
          PrismSkeleton(width: 72, height: 32),
          SizedBox(width: PrismSpacing.xs),
          PrismSkeleton(width: 64, height: 32),
          Spacer(),
          PrismSkeleton(width: 72, height: 32),
        ],
      );
    }
    return Row(
      children: <Widget>[
        // The permanent way into « Ma série ». The badge keeps its size; only the
        // touch area grows to the 44 pt floor. The container keeps it one
        // VoiceOver element: without it, this row's gems and XP labels would be
        // read as part of the same button.
        Semantics(
          container: true,
          hint: StreakLabels.badgeHint,
          child: PrismPressable(
            borderRadius: PrismRadii.pillAll,
            onPressed: () => context.push(Routes.streak),
            child: PrismTapTarget(
              child: StreakBadge(days: me.streakDays, active: me.dailyProgress >= 1),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GemCounter(gems: me.gems),
        const Spacer(),
        XpChip(xp: me.xp),
      ],
    );
  }
}

/// The certification-scoped band: readiness when a track is active, an
/// invitation when none is, an inline retry when the path fails to load.
///
/// The invitation reuses [ActivePathScreen]'s vocabulary verbatim —
/// [PrismStatusView] plus a way back to the library — because both surfaces
/// answer the same question and should answer it the same way.
class _TrackBand extends StatelessWidget {
  const _TrackBand({required this.state, required this.onRetry});

  final AsyncValue<LearningPath?> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const PrismSkeleton(height: 220),
      error: (Object error, StackTrace _) => PrismStatusView.error(
        message: HomeLabels.pathUnavailable,
        onRetry: onRetry,
      ),
      data: (LearningPath? path) {
        if (path == null) {
          return PrismStatusView(
            icon: Icons.school_outlined,
            title: HomeLabels.noTrackTitle,
            message: HomeLabels.noTrackMessage,
            actionLabel: HomeLabels.noTrackAction,
            onAction: () => context.go(Routes.library),
          );
        }
        return _ReadinessCard(path: path);
      },
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.path});

  final LearningPath path;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final int previous = (path.readinessScore - path.readinessTrend7d).clamp(0, 100);
    return PrismCard(
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
    );
  }
}

/// The learner's own day — goal and share. Independent of any certification,
/// so it survives a missing or failing track.
class _DailyBand extends StatelessWidget {
  const _DailyBand({required this.profile, required this.trackCode, required this.onRetry});

  final AsyncValue<UserProfile> profile;
  final String trackCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return profile.when(
      loading: () => const Column(
        children: <Widget>[
          PrismSkeleton(height: 72),
          SizedBox(height: 16),
          PrismSkeleton(height: 96),
        ],
      ),
      error: (Object error, StackTrace _) => PrismStatusView.error(
        message: HomeLabels.profileUnavailable,
        onRetry: onRetry,
      ),
      data: (UserProfile me) => Column(
        children: <Widget>[
          _DailyGoalCard(
            progress: me.dailyProgress,
            earned: me.dailyXpEarned,
            goal: me.dailyGoalXp,
          ),
          const SizedBox(height: 16),
          _DailyShareEntryCard(
            goalMet: me.dailyGoalXp > 0 && me.dailyXpEarned >= me.dailyGoalXp,
            trackCode: trackCode,
            onTap: () => context.push(Routes.dailyShare),
          ),
        ],
      ),
    );
  }
}

class _HomeGreeting extends StatefulWidget {
  const _HomeGreeting({required this.firstName, required this.subtitle});

  /// Null while the profile is still loading — the bubble greets without a name
  /// rather than collapsing, so the band keeps its height.
  final String? firstName;
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
                    widget.firstName == null
                        ? 'Bon retour 👋'
                        : 'Bon retour, ${widget.firstName} 👋',
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
                      : 'Transforme tes progrès du jour en carte de partage prête à envoyer.',
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
