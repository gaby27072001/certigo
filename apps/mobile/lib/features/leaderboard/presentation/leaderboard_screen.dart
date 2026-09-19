import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../shared/widgets/async_module.dart';

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
        child: RefreshIndicator(
          onRefresh: () => refreshQuietly(() => ref.refresh(leagueProvider.future)),
          child: AsyncModule<League>(
            state: async,
            errorMessage: LeagueLabels.unavailable,
            onRetry: () => ref.invalidate(leagueProvider),
            loading: (BuildContext context) => const _LeaderboardLoading(),
            data: (BuildContext context, League league) => _LeagueContent(league: league),
          ),
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
    final int promote = league.promoteCount;
    final PrismColorScheme p = context.prism;
    // A cut only exists when more learners are present than promote. Below that
    // the whole cohort moves up, and the header must not promise a line the
    // list cannot draw.
    final bool hasCut = league.entries.length > promote;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _LeagueHeader(league: league, hasCut: hasCut),
        ),
        if (league.entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            // The cohort came back empty — that is data, not a failure, and
            // the message already named the way in. Now it is a control.
            child: PrismStatusView(
              icon: Icons.groups_rounded,
              title: LeagueLabels.emptyTitle,
              message: LeagueLabels.emptyMessage,
              actionLabel: LeagueLabels.emptyAction,
              actionIcon: Icons.play_arrow_rounded,
              onAction: () => context.go(Routes.path),
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
                return Column(
                  children: <Widget>[
                    _EntryRow(entry: e, rank: i + 1, isMe: isMe),
                    if (hasCut && i == promote - 1) const _PromotionDivider(),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        // A short cohort ends at the foot of the viewport rather than trailing
        // off mid-screen: header at the top, standings below it, and the rule
        // that applies to them anchored at the bottom. The space between is
        // then deliberate, not an unfinished edge. When the list overflows,
        // the remaining space is zero and this costs nothing.
        if (league.entries.isNotEmpty && !hasCut)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PrismSpacing.gutter,
                  PrismSpacing.lg,
                  PrismSpacing.gutter,
                  PrismSpacing.xl,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.trending_up_rounded, size: 18, color: p.success),
                    const SizedBox(width: PrismSpacing.xs),
                    Flexible(
                      child: Text(
                        LeagueLabels.everyonePromotes,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: p.success),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Copy asserted by tests. Named so a wording change cannot silently turn a
/// widget test red from an unrelated branch.
abstract final class LeagueLabels {
  static const String everyonePromotes = 'Toute la cohorte monte cette semaine';
  static const String promotionZone = 'ZONE DE PROMOTION';
  static const String unavailable = 'Impossible de charger la ligue.';
  static const String emptyTitle = 'Pas encore de ligue';
  static const String emptyMessage = 'Termine une leçon pour rejoindre la ligue de la semaine.';
  static const String emptyAction = 'Commencer une leçon';

  static String cut(int promote) => 'top $promote montent';
}

/// The league's anchor. A short cohort leaves most of the viewport unused, so
/// the header is given the room instead of sitting as a hairline above a stub
/// list. Typographic rather than a card: the rows are already cards, and cards
/// stacked as page structure read as filler.
class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader({required this.league, required this.hasCut});

  final League league;
  final bool hasCut;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color tone = _tierColor(p, league.tier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.md,
        PrismSpacing.gutter,
        PrismSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: p.brightness == Brightness.dark ? 0.20 : 0.12),
              borderRadius: PrismRadii.cardLg,
              border: Border.all(color: tone.withValues(alpha: 0.24)),
            ),
            child: Icon(Icons.emoji_events_rounded, color: tone, size: 26),
          ),
          const SizedBox(width: PrismSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_tierLabel(league.tier), style: t.titleLarge),
                const SizedBox(height: PrismSpacing.xxs),
                Text(
                  _endsInLabel(league.endsAt),
                  style: t.bodySmall?.copyWith(color: p.textSecondary),
                ),
                if (hasCut) ...<Widget>[
                  const SizedBox(height: PrismSpacing.xs),
                  Text(
                    LeagueLabels.cut(league.promoteCount),
                    style: t.labelMedium?.copyWith(color: p.success),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
          _RankMark(rank: rank),
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
          // One line per learner: a long name plus the "(vous)" suffix used to
          // wrap, making that single row taller than every other and breaking
          // the list's rhythm exactly where the eye is drawn. The name yields
          // first — the "vous" marker never truncates, because it is the one
          // thing the learner scans this list for.
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isMe)
                  Text(
                    ' (vous)',
                    style: t.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: PrismSpacing.xs),
          Text('${entry.weeklyXp} XP', style: t.labelLarge?.copyWith(color: p.textSecondary)),
        ],
      ),
    );
  }
}

/// The podium mark. Ranks 1-3 carry a filled disc; everyone else is a plain
/// numeral.
///
/// Colour alone cannot carry this podium: in the light theme `xpGold` is
/// `#924A13` and `ember` is `#B02013` — a brown and a red, near-identical at
/// 14pt, and `ember` also means "to reinforce" everywhere else in the app. The
/// disc makes the top three legible as a group before any hue is read, which is
/// also what keeps it working for colour-blind learners.
///
/// It generalises the tinted-container pattern already used by
/// [PrismStatusView] and Home's Explore tiles rather than inventing one.
class _RankMark extends StatelessWidget {
  const _RankMark({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool dark = p.brightness == Brightness.dark;
    final Color? tone = podiumTone(p, rank);

    if (tone == null) {
      return SizedBox(
        width: 30,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: t.titleMedium?.copyWith(color: p.textSecondary, fontWeight: FontWeight.w800),
        ),
      );
    }
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: dark ? 0.22 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: tone.withValues(alpha: 0.34)),
      ),
      child: Text(
        '$rank',
        style: t.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Gold / silver / bronze for ranks 1-3, null below.
///
/// The medals are a colour **role** now, resolved by [PrismColorScheme] across
/// all eight shipped appearances, rather than two literals held here. That is
/// what puts them inside `prism_contrast_contract_test`: a value written in a
/// screen is invisible to the design system's guards, which is precisely how
/// silver reached **1.79:1** on the light card and stayed there.
Color? podiumTone(PrismColorScheme p, int rank) => p.medalFor(rank);

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
              LeagueLabels.promotionZone,
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

/// The tier's identity colour.
///
/// Bronze, Silver and Gold tiers reuse the podium medals: a Bronze league and a
/// third place are the same idea at two scales, and giving them two different
/// browns would say they are unrelated.
Color _tierColor(PrismColorScheme p, LeagueTier tier) {
  return switch (tier) {
    LeagueTier.bronze => p.medalFor(3)!,
    LeagueTier.silver => p.medalFor(2)!,
    LeagueTier.gold => p.medalFor(1)!,
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
  final List<String> parts =
      name.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  final String a = parts.first.substring(0, 1);
  final String b = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (a + b).toUpperCase();
}
