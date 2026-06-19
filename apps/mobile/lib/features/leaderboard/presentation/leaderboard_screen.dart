import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

/// Leaderboard — the weekly "Momentum League". Cohort of ~30, tiered, with a
/// clear promotion zone. Framed positively: we highlight the promotion line and
/// the learner's own row, never shame the bottom. Sample data pending
/// `leaderboardRepositoryProvider` in P2.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  static const int _promoteCount = 7;
  static const String _meId = 'u-jordan';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.emoji_events_rounded, color: p.xpGold, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Ligue Or', style: t.headlineMedium),
                              Text('Se termine dans 3 jours · top $_promoteCount montent',
                                  style: t.bodySmall?.copyWith(color: p.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList.builder(
                itemCount: _sample.length,
                itemBuilder: (BuildContext context, int i) {
                  final _Entry e = _sample[i];
                  final bool isMe = e.userId == _meId;
                  final bool promotionLine = i == _promoteCount - 1;
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
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.rank, required this.isMe});
  final _Entry entry;
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
    return GlassSurface(
      elevation: isMe ? 2 : 0,
      tint: isMe ? p.primary : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(color: rankColor, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: p.primarySoft,
            child: Text(entry.initials,
                style: t.labelMedium?.copyWith(color: p.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(isMe ? '${entry.name} (vous)' : entry.name,
                style: t.bodyLarge?.copyWith(fontWeight: isMe ? FontWeight.w800 : FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: p.success, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('ZONE DE PROMOTION',
                style: t.labelSmall
                    ?.copyWith(color: p.success, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          Expanded(child: Divider(color: p.success, thickness: 1.5)),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry(this.userId, this.name, this.initials, this.weeklyXp);
  final String userId;
  final String name;
  final String initials;
  final int weeklyXp;
}

const List<_Entry> _sample = <_Entry>[
  _Entry('u-amara', 'Amara K.', 'AK', 980),
  _Entry('u-li', 'Li Wei', 'LW', 910),
  _Entry('u-sven', 'Sven P.', 'SP', 870),
  _Entry('u-jordan', 'Jordan Doe', 'JD', 820),
  _Entry('u-noa', 'Noa B.', 'NB', 760),
  _Entry('u-priya', 'Priya R.', 'PR', 700),
  _Entry('u-tom', 'Tom H.', 'TH', 640),
  _Entry('u-mara', 'Mara S.', 'MS', 590),
  _Entry('u-ken', 'Ken O.', 'KO', 520),
  _Entry('u-eva', 'Eva L.', 'EL', 480),
];
