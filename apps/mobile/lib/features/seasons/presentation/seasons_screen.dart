import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/inline_error.dart';
import '../../../shared/widgets/screen_header.dart';

/// Seasons — the monthly themed campaign. One headline challenge with a badge
/// and a gem reward. Fed by `seasonProvider`; claiming posts a
/// [ClaimSeasonRequest] and, on success, invalidates the provider so the board
/// refetches the authoritative state. Errors are surfaced inline (this screen
/// sits above the shell, so there is no Scaffold/SnackBar host).
class SeasonsScreen extends ConsumerWidget {
  const SeasonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Season> async = ref.watch(seasonProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const ScreenHeader(title: 'Saison'),
            Expanded(
              child: async.when(
                data: (Season season) => _SeasonContent(season: season),
                loading: () => const _SeasonLoading(),
                error: (Object error, StackTrace _) => PrismStatusView.error(
                  onRetry: () => ref.invalidate(seasonProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonContent extends ConsumerStatefulWidget {
  const _SeasonContent({required this.season});

  final Season season;

  @override
  ConsumerState<_SeasonContent> createState() => _SeasonContentState();
}

class _SeasonContentState extends ConsumerState<_SeasonContent> {
  bool _claiming = false;
  String? _error;

  Future<void> _claim() async {
    setState(() {
      _claiming = true;
      _error = null;
    });
    final Result<ClaimSeasonResult> result = await ref.read(seasonRepositoryProvider).claimSeason(
          ClaimSeasonRequest(seasonId: widget.season.id),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (ClaimSeasonResult r) {
        setState(() {
          _claiming = false;
          _error = r.success ? null : (r.error ?? 'La récompense n\'a pas pu être réclamée.');
        });
        if (r.success) {
          ref.invalidate(seasonProvider);
        }
      },
      failure: (Failure f) {
        setState(() {
          _claiming = false;
          _error = f.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Season season = widget.season;
    final SeasonChallenge challenge = season.challenge;
    final Color accent = _accentColor(season.accent, p.primary);
    final double progress = challenge.target > 0
        ? (challenge.current / challenge.target).clamp(0.0, 1.0)
        : (challenge.completed ? 1.0 : 0.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: <Widget>[
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: accent,
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: PrismRadii.cardMd,
                    ),
                    child: Text(
                      season.mascot,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(season.theme, style: t.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${_monthName(season.month)} ${season.year}',
                          style: t.labelMedium?.copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  GemCounter(gems: season.gems),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                season.tagline,
                style: t.bodyLarge?.copyWith(color: p.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.flag_rounded, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(challenge.title, style: t.titleMedium)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PrismProgressBar(
                      value: progress,
                      gradient: <Color>[accent, accent],
                      semanticLabel: 'Progression du défi de saison',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${challenge.current}/${challenge.target}',
                    style: t.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.diamond_rounded, size: 16, color: p.info),
                  const SizedBox(width: 6),
                  Text(
                    'Récompense : ${challenge.rewardGems} gemmes',
                    style: t.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                  const Spacer(),
                  _BadgePill(title: season.badgeTitle, accent: accent),
                ],
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 14),
                InlineError(message: _error!),
              ],
              const SizedBox(height: 16),
              PrismButton(
                label: challenge.claimed
                    ? 'Badge et gemmes obtenus'
                    : 'Réclamer ${challenge.rewardGems} gemmes',
                icon: challenge.claimed ? Icons.verified_rounded : Icons.card_giftcard_rounded,
                loading: _claiming,
                onPressed: (challenge.claimable && !_claiming) ? _claim : null,
              ),
              if (!challenge.completed && !challenge.claimed) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Termine le défi pour débloquer la récompense.',
                  style: t.bodySmall?.copyWith(color: p.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.title, required this.accent});

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.16),
        borderRadius: PrismRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.military_tech_rounded, size: 14, color: accent),
          const SizedBox(width: 4),
          Text(
            title,
            style: t.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SeasonLoading extends StatelessWidget {
  const _SeasonLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: const <Widget>[
        PrismSkeleton(height: 132),
        SizedBox(height: 16),
        PrismSkeleton(height: 180),
      ],
    );
  }
}

Color _accentColor(String hex, Color fallback) {
  final String cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6) {
    return fallback;
  }
  final int? value = int.tryParse(cleaned, radix: 16);
  if (value == null) {
    return fallback;
  }
  return Color(value | 0xFF000000);
}

String _monthName(int month) {
  const List<String> names = <String>[
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  if (month < 1 || month > 12) {
    return 'Saison';
  }
  return names[month - 1];
}
