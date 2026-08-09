import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';

/// Leaderboard — the weekly "Momentum League". Cohort of ~30, tiered, with a
/// clear promotion zone. Framed positively: we highlight the promotion line and
/// the learner's own row, never shame the bottom. Driven by `leagueProvider`
/// (real standings from the API) with skeleton loading and a retry error state.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<League> async = ref.watch(leagueProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: async.when(
          data: (League league) => _LeagueContent(league: league),
          loading: () => const _LeaderboardLoading(),
          error: (Object error, StackTrace _) =>
              PrismStatusView.error(onRetry: () => ref.invalidate(leagueProvider)),
        ),
      ),
    );
  }
}

class _LeagueContent extends StatelessWidget {
  const _LeagueContent({required this.league});

  final League league;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color tierColor = _tierColor(p, league.tier);
    final int promote = league.promoteCount;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PrismSpacing.gutter,
              PrismSpacing.sm,
              PrismSpacing.gutter,
              PrismSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.emoji_events_rounded, color: tierColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_tierLabel(league.tier), style: t.headlineMedium),
                      Text(
                        '${_endsInLabel(league.endsAt)} · top $promote montent',
                        style: t.bodySmall?.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (league.entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PrismStatusView(
              icon: Icons.groups_rounded,
              title: 'Pas encore de ligue',
              message: 'Termine une leçon pour rejoindre la ligue de la semaine.',
            ),
          )
        else
          SliverPadding(
            padding: PrismSpacing.scrollBody(),
            sliver: SliverList.builder(
              itemCount: league.entries.length,
              itemBuilder: (BuildContext context, int i) {
                final LeaderboardEntry e = league.entries[i];
                final bool isMe = e.userId == league.meUserId;
                final bool promotionLine = i == promote - 1 && league.entries.length > promote;
                return Column(
                  children: <Widget>[
                    _EntryRow(entry: e, rank: i + 1, isMe: isMe),
                    if (promotionLine) const _PromotionDivider(),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.rank, required this.isMe});

  final LeaderboardEntry entry;
  final int rank;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color rankColor = switch (rank) {
      1 => p.xpGold,
      2 => const Color(0xFFB8C2D9),
      3 => p.ember,
      _ => p.textSecondary,
    };
    return PrismCard(
      variant: isMe ? PrismCardVariant.tonal : PrismCardVariant.surface,
      accent: isMe ? p.primary : null,
      elevation: isMe ? 2 : 0,
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.debt14,
        vertical: PrismSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: rankColor, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: p.primarySoft,
            child: Text(
              _initials(entry.displayName),
              style: t.labelMedium?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${entry.displayName} (vous)' : entry.displayName,
              style: t.bodyLarge?.copyWith(fontWeight: isMe ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
          Text('${entry.weeklyXp} XP', style: t.labelLarge?.copyWith(color: p.textSecondary)),
        ],
      ),
    );
  }
}

class _PromotionDivider extends StatelessWidget {
  const _PromotionDivider();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrismSpacing.debt10),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: p.success, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.debt10),
            child: Text(
              'ZONE DE PROMOTION',
              style: t.labelSmall?.copyWith(
                color: p.success,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Divider(color: p.success, thickness: 1.5)),
        ],
      ),
    );
  }
}

class _LeaderboardLoading extends StatelessWidget {
  const _LeaderboardLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
      children: const <Widget>[
        PrismSkeleton(width: 180, height: 26),
        SizedBox(height: 20),
        PrismSkeleton(height: 64),
        SizedBox(height: 10),
        PrismSkeleton(height: 64),
        SizedBox(height: 10),
        PrismSkeleton(height: 64),
        SizedBox(height: 10),
        PrismSkeleton(height: 64),
      ],
    );
  }
}

String _tierLabel(LeagueTier tier) {
  return switch (tier) {
    LeagueTier.bronze => 'Ligue Bronze',
    LeagueTier.silver => 'Ligue Argent',
    LeagueTier.gold => 'Ligue Or',
    LeagueTier.platinum => 'Ligue Platine',
    LeagueTier.diamond => 'Ligue Diamant',
  };
}

Color _tierColor(PrismColorScheme p, LeagueTier tier) {
  return switch (tier) {
    LeagueTier.bronze => p.ember,
    LeagueTier.silver => const Color(0xFFB8C2D9),
    LeagueTier.gold => p.xpGold,
    LeagueTier.platinum => p.info,
    LeagueTier.diamond => p.primary,
  };
}

String _endsInLabel(DateTime endsAt) {
  final Duration left = endsAt.difference(DateTime.now());
  if (left.isNegative) {
    return 'Ligue terminée';
  }
  if (left.inDays >= 1) {
    return 'Se termine dans ${left.inDays} j';
  }
  if (left.inHours >= 1) {
    return 'Se termine dans ${left.inHours} h';
  }
  return 'Se termine bientôt';
}

String _initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  final String a = parts.first.substring(0, 1);
  final String b = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (a + b).toUpperCase();
}
