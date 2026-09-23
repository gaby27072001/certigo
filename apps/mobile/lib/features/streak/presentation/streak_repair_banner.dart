import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import 'streak_copy.dart';

/// The Home prompt that makes a repairable streak *visible*: without it the
/// offer would exist only for a learner who thought to tap the streak badge.
///
/// Self-hiding, like the coach shelf: nothing while loading, on error, or when
/// the server offers no repair — Home never waits on it, and a failure here
/// takes nothing else down.
///
/// Home stays mounted for the whole session, so its snapshot can outlive the day
/// it describes. It is re-read whenever the app returns to the foreground; the
/// « Ma série » screen re-reads it again before any gem is spent.
class StreakRepairBanner extends ConsumerStatefulWidget {
  const StreakRepairBanner({super.key});

  @override
  ConsumerState<StreakRepairBanner> createState() => _StreakRepairBannerState();
}

class _StreakRepairBannerState extends ConsumerState<StreakRepairBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(streakStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StreakStatus? status = ref.watch(streakStatusProvider).valueOrNull;
    if (status == null || status.offer != StreakRepairOffer.available) {
      return const SizedBox.shrink();
    }

    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool covered = status.coveredByFreeze;
    final Color tone = covered ? p.info : p.ember;
    final DateTime? expires = status.repairExpiresAt;
    final String? until = expires == null
        ? null
        : formatRepairDeadline(
            MaterialLocalizations.of(context),
            expires.toLocal(),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpacing.md),
      child: PrismCard(
        variant: PrismCardVariant.tonal,
        accent: tone,
        onTap: () => context.push(Routes.streak),
        child: Row(
          children: <Widget>[
            Icon(
              covered ? Icons.ac_unit_rounded : Icons.local_fire_department_rounded,
              color: tone,
              size: 28,
            ),
            const SizedBox(width: PrismSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    covered
                        ? StreakLabels.bannerFreezeTitle
                        : StreakLabels.bannerTitle(status.streakDays),
                    style: t.titleMedium,
                  ),
                  const SizedBox(height: PrismSpacing.xxs),
                  Text(
                    covered
                        ? StreakLabels.bannerFreezeBody(status.streakDays)
                        : StreakLabels.bannerBody(status.repairCostGems, until),
                    style: t.bodySmall?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PrismSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}
