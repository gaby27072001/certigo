import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../shared/errors/error_copy.dart';
import '../../../shared/widgets/async_module.dart';
import '../../../shared/widgets/screen_header.dart';
import '../application/streak_repair_controller.dart';
import 'streak_copy.dart';

/// « Ma série » — the learner's streak and, when the server offers one, its paid
/// repair.
///
/// Everything shown comes from `GET /streak` and from the server's ruling on
/// `POST /streak/repair`; the screen formats server values and never re-derives
/// eligibility, price, balance or window (docs/contracts/learner-streak/v1).
///
/// States, one module: skeleton while nothing has arrived; a cause-and-action
/// error when the first read fails; the content, kept on screen with a stale
/// banner when a refresh fails; and, within the content, one view per offer the
/// server can make.
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  @override
  void initState() {
    super.initState();
    // Home keeps this snapshot alive, possibly from hours ago. Paying is decided
    // on a fresh read: a value cached before the screen opened is re-read now,
    // and the repair stays disabled until that read lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AsyncValue<StreakStatus> cached = ref.read(streakStatusProvider);
      if (cached.hasValue && !cached.isLoading) {
        ref.invalidate(streakStatusProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<StreakStatus> status = ref.watch(streakStatusProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const ScreenHeader(title: StreakLabels.title),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => refreshQuietly(() => ref.refresh(streakStatusProvider.future)),
                // A cold failure gets the cause-and-action copy of `describeFailure`
                // instead of AsyncModule's generic « Connexion impossible »: a 5xx
                // is not a connection problem, and saying so would send the learner
                // to fix what is not broken.
                child: !status.hasValue && status.hasError
                    ? ScrollableStatus(
                        child: _StatusError(
                          error: status.error,
                          onRetry: () => ref.invalidate(streakStatusProvider),
                        ),
                      )
                    : AsyncModule<StreakStatus>(
                        state: status,
                        loading: (BuildContext context) => const _StreakLoading(),
                        data: (BuildContext context, StreakStatus value) =>
                            _StreakContent(status: value),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusError extends StatelessWidget {
  const _StatusError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ErrorCopy copy = streakStatusErrorCopy(error);
    return PrismStatusView(
      icon: copy.icon,
      title: copy.title,
      message: copy.message,
      actionLabel: copy.actionLabel,
      actionIcon: copy.actionIcon,
      onAction: copy.retryResolves ? onRetry : () => context.go(Routes.home),
    );
  }
}

class _StreakContent extends ConsumerWidget {
  const _StreakContent({required this.status});

  final StreakStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StreakRepairState repair = ref.watch(streakRepairControllerProvider);
    // A snapshot is only good enough to pay on when its latest read landed.
    // Measured in review: after a failed re-read Riverpod keeps the old value
    // beside the error and `isLoading` falls back to false — the snapshot on
    // screen may be hours old, yet it would have let the repair go through.
    final ({bool loading, bool failed}) read = ref.watch(
      streakStatusProvider.select(
        (AsyncValue<StreakStatus> s) => (loading: s.isLoading, failed: s.hasError),
      ),
    );

    final Widget view;
    final String viewKey;
    if (repair.phase == StreakRepairPhase.granted) {
      view = _GrantedView(result: repair.result!);
      viewKey = 'granted';
    } else if (status.offer == StreakRepairOffer.available) {
      view = _OfferView(
        status: status,
        repair: repair,
        checking: read.loading,
        unverified: !read.loading && read.failed,
      );
      viewKey = 'offer';
    } else {
      view = _NoOfferView(status: status, repair: repair);
      viewKey = 'no-offer-${status.offer.name}';
    }

    // One element becoming another: the offer card settles into its outcome
    // rather than being swapped. Zero under reduced motion.
    return AnimatedSwitcher(
      duration: PrismMotion.resolve(context, PrismMotion.morph),
      switchInCurve: PrismMotion.continuous,
      switchOutCurve: PrismMotion.continuous,
      child: KeyedSubtree(key: ValueKey<String>(viewKey), child: view),
    );
  }
}

// ── The offer ─────────────────────────────────────────────────────────────

class _OfferView extends ConsumerWidget {
  const _OfferView({
    required this.status,
    required this.repair,
    required this.checking,
    required this.unverified,
  });

  final StreakStatus status;
  final StreakRepairState repair;

  /// A read of the snapshot is in flight.
  final bool checking;

  /// The latest read failed: the snapshot on screen may be old.
  final bool unverified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final int short = status.gemsShort ?? 0;
    final bool canRepair = !checking && !unverified && !repair.repairing && short == 0;
    final DateTime? expires = status.repairExpiresAt;
    final DateTime? lastActive = status.lastActiveDate;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: <Widget>[
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: p.ember,
          child: Column(
            children: <Widget>[
              // Cooled, like StreakBadge when the day is not secured: the flame
              // is out, and that is the information.
              Icon(Icons.local_fire_department_rounded, size: 40, color: p.textSecondary),
              const SizedBox(height: PrismSpacing.xs),
              Text(
                StreakLabels.pausedTitle(status.streakDays),
                style: t.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (lastActive != null) ...<Widget>[
                const SizedBox(height: PrismSpacing.xxs),
                Text(
                  StreakLabels.lastActive(formatStreakDay(l10n, lastActive)),
                  style: t.bodyMedium?.copyWith(color: p.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        if (status.coveredByFreeze) ...<Widget>[
          const SizedBox(height: PrismSpacing.sm),
          PrismCard(
            variant: PrismCardVariant.tonal,
            accent: p.info,
            child: _Fact(
              icon: Icons.ac_unit_rounded,
              tone: p.info,
              title: StreakLabels.freezeTitle,
              text: StreakLabels.freezeBody(status.streakDays),
            ),
          ),
        ],
        const SizedBox(height: PrismSpacing.sm),
        PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  StreakLabels.offerTitle,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: PrismSpacing.xxs),
              Text(
                StreakLabels.offerBody(status.streakDays),
                style: t.bodyMedium?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: PrismSpacing.sm),
              if (status.coveredByFreeze)
                _Fact(
                  icon: Icons.ac_unit_rounded,
                  tone: p.info,
                  text: StreakLabels.freezeRepairNote,
                )
              else
                _Fact(
                  icon: Icons.warning_amber_rounded,
                  tone: p.warning,
                  text: StreakLabels.beforeGoal,
                ),
              const SizedBox(height: PrismSpacing.xs),
              _Fact(
                icon: Icons.diamond_rounded,
                tone: p.info,
                text: StreakLabels.price(status.repairCostGems),
              ),
              if (status.gems case final int gems) ...<Widget>[
                const SizedBox(height: PrismSpacing.xs),
                _Fact(
                  icon: Icons.account_balance_wallet_rounded,
                  tone: p.info,
                  text: StreakLabels.balance(gems),
                ),
              ],
              const SizedBox(height: PrismSpacing.xs),
              _Fact(
                icon: Icons.schedule_rounded,
                tone: p.textSecondary,
                text: expires == null
                    ? StreakLabels.noDeadline
                    : StreakLabels.deadline(
                        formatRepairDeadline(
                          l10n,
                          expires.toLocal(),
                          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                        ),
                      ),
              ),
              if (short > 0) ...<Widget>[
                const SizedBox(height: PrismSpacing.sm),
                _Fact(
                  icon: Icons.info_outline_rounded,
                  tone: p.warning,
                  title: StreakLabels.missing(short),
                  // With a freeze covering the gap, meeting the goal saves the
                  // streak; the reset warning would say the opposite.
                  text: status.coveredByFreeze
                      ? StreakLabels.missingFreezeHint
                      : StreakLabels.missingHint,
                ),
              ],
              if (_notice(repair) case final _NoticeCopy notice) ...<Widget>[
                const SizedBox(height: PrismSpacing.sm),
                _Notice(copy: notice),
              ],
              if (unverified) ...<Widget>[
                const SizedBox(height: PrismSpacing.sm),
                _Fact(
                  icon: Icons.sync_problem_rounded,
                  tone: p.warning,
                  title: StreakLabels.unverifiedTitle,
                  text: StreakLabels.unverifiedBody,
                ),
                const SizedBox(height: PrismSpacing.xs),
                // A button, not only the pull gesture: VoiceOver cannot pull.
                PrismButton.secondary(
                  label: StreakLabels.recheck,
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(streakStatusProvider),
                ),
              ],
              const SizedBox(height: PrismSpacing.md),
              if (checking) ...<Widget>[
                Text(
                  StreakLabels.checking,
                  style: t.labelMedium?.copyWith(color: p.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PrismSpacing.xs),
              ],
              PrismButton(
                variant: status.coveredByFreeze
                    ? PrismButtonVariant.secondary
                    : PrismButtonVariant.primary,
                label: status.coveredByFreeze ? StreakLabels.repairAnyway : StreakLabels.repair,
                icon: Icons.restore_rounded,
                loading: repair.repairing,
                // The one engagement of this screen: gems are spent. The vocabulary
                // names `light` for « tu viens d'engager quelque chose », and no
                // other layer vibrates for this gesture.
                haptic: PrismHaptic.light,
                onPressed: canRepair
                    ? () => ref.read(streakRepairControllerProvider.notifier).repair()
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Granted ───────────────────────────────────────────────────────────────

class _GrantedView extends StatelessWidget {
  const _GrantedView({required this.result});

  final StreakRepairResult result;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: <Widget>[
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: p.success,
          elevation: 2,
          child: Semantics(
            // Announced as it appears: the ruling is the answer to the tap.
            liveRegion: true,
            container: true,
            child: Column(
              children: <Widget>[
                Icon(Icons.local_fire_department_rounded, size: 40, color: p.ember),
                const SizedBox(height: PrismSpacing.xs),
                Text(StreakLabels.grantedTitle, style: t.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: PrismSpacing.xxs),
                Text(
                  StreakLabels.grantedBody(result.streakDays),
                  style: t.bodyMedium?.copyWith(color: p.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PrismSpacing.sm),
                Text(
                  StreakLabels.newBalance(result.gemsBalance),
                  style: t.labelLarge?.copyWith(color: p.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PrismSpacing.md),
        PrismButton(
          label: StreakLabels.continueLearning,
          icon: Icons.school_rounded,
          onPressed: () => context.go(Routes.path),
        ),
      ],
    );
  }
}

// ── No offer ──────────────────────────────────────────────────────────────

class _NoOfferView extends StatelessWidget {
  const _NoOfferView({required this.status, required this.repair});

  final StreakStatus status;
  final StreakRepairState repair;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final (IconData icon, Color tone, String title, String message, String action) =
        switch (status.offer) {
      StreakRepairOffer.intact => (
          Icons.local_fire_department_rounded,
          p.ember,
          StreakLabels.intactTitle(status.streakDays),
          status.freezeTokens > 0
              ? '${StreakLabels.intactBody}\n${StreakLabels.freezeReserve(status.freezeTokens)}'
              : StreakLabels.intactBody,
          StreakLabels.continueLearning,
        ),
      StreakRepairOffer.expired => (
          Icons.hourglass_disabled_rounded,
          p.warning,
          StreakLabels.expiredTitle(status.streakDays),
          StreakLabels.expiredBody,
          StreakLabels.startLesson,
        ),
      StreakRepairOffer.none => (
          Icons.local_fire_department_outlined,
          p.primary,
          StreakLabels.noneTitle,
          StreakLabels.noneBody,
          StreakLabels.startLesson,
        ),
      StreakRepairOffer.unavailable || StreakRepairOffer.available => (
          Icons.info_outline_rounded,
          p.info,
          StreakLabels.unavailableTitle,
          StreakLabels.unavailableBody,
          StreakLabels.continueLearning,
        ),
    };
    final _NoticeCopy? notice = _notice(repair);

    return ScrollableStatus(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                PrismSpacing.md,
                PrismSpacing.gutter,
                0,
              ),
              child: _Notice(copy: notice),
            ),
          PrismStatusView(
            icon: icon,
            tone: tone,
            title: title,
            message: message,
            actionLabel: action,
            actionIcon: Icons.school_rounded,
            onAction: () => context.go(Routes.path),
          ),
        ],
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────

/// What the last repair attempt left to say, if anything.
_NoticeCopy? _notice(StreakRepairState repair) {
  switch (repair.phase) {
    case StreakRepairPhase.refused:
      return _NoticeCopy(
        tone: _NoticeTone.warning,
        message: refusalMessage(repair.result!),
      );
    case StreakRepairPhase.failed:
      final ({String title, String message, bool retryResolves}) copy =
          repairFailureCopy(repair.failure);
      return _NoticeCopy(tone: _NoticeTone.error, title: copy.title, message: copy.message);
    case StreakRepairPhase.idle:
    case StreakRepairPhase.repairing:
    case StreakRepairPhase.granted:
      return null;
  }
}

enum _NoticeTone { warning, error }

class _NoticeCopy {
  const _NoticeCopy({required this.tone, required this.message, this.title});

  final _NoticeTone tone;
  final String? title;
  final String message;
}

/// The outcome of the last attempt, announced as it appears.
class _Notice extends StatelessWidget {
  const _Notice({required this.copy});

  final _NoticeCopy copy;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Color tone = copy.tone == _NoticeTone.error ? p.error : p.warning;
    return Semantics(
      liveRegion: true,
      container: true,
      child: PrismCard(
        variant: PrismCardVariant.outlined,
        accent: tone,
        elevation: 0,
        padding: PrismSpacing.cardPadding,
        borderRadius: PrismRadii.cardMd,
        child: _Fact(
          icon: copy.tone == _NoticeTone.error
              ? Icons.error_outline_rounded
              : Icons.info_outline_rounded,
          tone: tone,
          title: copy.title,
          text: copy.message,
        ),
      ),
    );
  }
}

/// One line of the offer: an icon and text that reflows at any text size. No
/// line here is ever truncated; a long one wraps.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.tone, required this.text, this.title});

  final IconData icon;
  final Color tone;
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: PrismSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (title != null) ...<Widget>[
                Text(title!, style: t.titleSmall?.copyWith(color: p.textPrimary)),
                const SizedBox(height: PrismSpacing.xxs),
              ],
              Text(text, style: t.bodyMedium?.copyWith(color: p.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakLoading extends StatelessWidget {
  const _StreakLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: const <Widget>[
        PrismSkeleton(height: 132),
        SizedBox(height: PrismSpacing.sm),
        PrismSkeleton(height: 280),
      ],
    );
  }
}
