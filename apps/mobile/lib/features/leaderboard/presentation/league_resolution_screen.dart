import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';

/// League resolution — the animated result screen shown after a weekly league
/// period closes. Displays whether the learner was promoted, stayed in their
/// tier or was relegated, with the new tier badge and final stats.
///
/// Navigated to from the leaderboard screen when
/// [leagueResolutionProvider] returns a non-null result.
class LeagueResolutionScreen extends ConsumerWidget {
  const LeagueResolutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LeagueResolution?> async =
        ref.watch(leagueResolutionProvider);

    return AuroraBackground(
      animate: true,
      child: SafeArea(
        child: async.when(
          data: (LeagueResolution? resolution) {
            if (resolution == null) {
              return const PrismStatusView(
                icon: Icons.emoji_events_rounded,
                title: 'Aucun résultat disponible',
                message: 'Les résultats seront visibles après la fin de ta première ligue.',
              );
            }
            return _ResolutionContent(resolution: resolution);
          },
          loading: () => const _ResolutionLoading(),
          error: (Object error, StackTrace _) => PrismStatusView.error(
            onRetry: () => ref.invalidate(leagueResolutionProvider),
          ),
        ),
      ),
    );
  }
}

class _ResolutionContent extends StatefulWidget {
  const _ResolutionContent({required this.resolution});
  final LeagueResolution resolution;

  @override
  State<_ResolutionContent> createState() => _ResolutionContentState();
}

class _ResolutionContentState extends State<_ResolutionContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final LeagueResolution r = widget.resolution;
    final bool reducedMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final (String headline, IconData icon, Color color, String subtitle) =
        switch (r.outcome) {
      ResolutionOutcome.promoted => (
          'Promotion !',
          Icons.arrow_upward_rounded,
          p.success,
          'Tu passes en ${_tierLabel(r.newTier)} 🎉',
        ),
      ResolutionOutcome.relegated => (
          'Relégation',
          Icons.arrow_downward_rounded,
          p.warning,
          'Tu passes en ${_tierLabel(r.newTier)}',
        ),
      ResolutionOutcome.stayed => (
          'Tu restes !',
          Icons.check_circle_rounded,
          p.info,
          'Tu restes en ${_tierLabel(r.newTier)}',
        ),
    };

    Widget body = ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(height: 16),

        // Outcome hero -----------------------------------------------------
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 52),
              ),
              const SizedBox(height: 16),
              Text(
                headline,
                style: t.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: t.titleMedium?.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Tier badge ----------------------------------------------------------
        PrismCard(
          elevation: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.emoji_events_rounded, color: _tierColor(p, r.newTier), size: 32),
              const SizedBox(width: 12),
              Text(
                _tierLabel(r.newTier),
                style: t.headlineSmall?.copyWith(
                  color: _tierColor(p, r.newTier),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats ---------------------------------------------------------------
        Row(
          children: <Widget>[
            _StatTile(
              label: 'Classement final',
              value: '#${r.finalRank}',
              icon: Icons.leaderboard_rounded,
              color: p.primary,
            ),
            const SizedBox(width: 12),
            _StatTile(
              label: 'XP cette semaine',
              value: '${r.finalWeeklyXp} XP',
              icon: Icons.bolt_rounded,
              color: p.xpGold,
            ),
          ],
        ),
        const SizedBox(height: 32),

        PrismButton(
          label: 'Retour à la ligue',
          icon: Icons.emoji_events_rounded,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );

    if (reducedMotion) return body;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: body),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

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

class _ResolutionLoading extends StatelessWidget {
  const _ResolutionLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      children: const <Widget>[
        PrismSkeleton(width: 96, height: 96),
        SizedBox(height: 16),
        PrismSkeleton(width: 160, height: 36),
        SizedBox(height: 8),
        PrismSkeleton(width: 200, height: 22),
        SizedBox(height: 32),
        PrismSkeleton(height: 64),
        SizedBox(height: 16),
        PrismSkeleton(height: 88),
      ],
    );
  }
}

String _tierLabel(LeagueTier tier) => switch (tier) {
      LeagueTier.bronze => 'Ligue Bronze',
      LeagueTier.silver => 'Ligue Argent',
      LeagueTier.gold => 'Ligue Or',
      LeagueTier.platinum => 'Ligue Platine',
      LeagueTier.diamond => 'Ligue Diamant',
    };

Color _tierColor(PrismColorScheme p, LeagueTier tier) => switch (tier) {
      LeagueTier.bronze => p.ember,
      LeagueTier.silver => const Color(0xFFB8C2D9),
      LeagueTier.gold => p.xpGold,
      LeagueTier.platinum => p.info,
      LeagueTier.diamond => p.primary,
    };
