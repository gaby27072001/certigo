import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';

/// Full-screen streak detail — daily-fire counter, freeze tokens and
/// the repair action. Pushed via `Navigator.push` as a modal route so it
/// sits above the app shell without a bottom-nav tab.
///
/// Opening it is triggered from [HomeScreen] (tap on [StreakBadge]) and from
/// [ProfileScreen] (streak stat tile tap).
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Streak> async = ref.watch(streakProvider);

    return AuroraBackground(
      animate: true,
      child: SafeArea(
        child: async.when(
          data: (Streak streak) => _StreakContent(streak: streak),
          loading: () => const _StreakLoading(),
          error: (Object error, StackTrace _) => PrismStatusView.error(
            onRetry: () => ref.invalidate(streakProvider),
          ),
        ),
      ),
    );
  }
}

class _StreakContent extends ConsumerWidget {
  const _StreakContent({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: <Widget>[
        // Close handle
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(height: 8),

        // Hero fire counter ------------------------------------------------
        Center(
          child: _StreakHero(days: streak.days),
        ),
        const SizedBox(height: 24),

        // Status chips -------------------------------------------------------
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _InfoChip(
              icon: Icons.ac_unit_rounded,
              label: '${streak.freezeTokens} gel${streak.freezeTokens == 1 ? '' : 's'}',
              color: p.info,
              tooltip: 'Jetons de gel — protègent la série en cas de jour manqué',
            ),
            if (streak.repairedToday)
              _InfoChip(
                icon: Icons.auto_fix_high_rounded,
                label: 'Réparée aujourd\'hui',
                color: p.success,
              ),
          ],
        ),
        const SizedBox(height: 32),

        // Repair section ------------------------------------------------------
        if (streak.canRepair && !streak.repairedToday)
          _RepairCard(
            costGems: streak.repairCostGems,
            onRepaired: () => ref.invalidate(streakProvider),
          )
        else if (!streak.canRepair && streak.days == 0)
          PrismCard(
            variant: PrismCardVariant.tonal,
            accent: p.ember,
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.local_fire_department_rounded,
                  color: p.ember,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Lance ta série !',
                  style: t.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Termine une leçon aujourd\'hui pour démarrer ta série.',
                  style: t.bodySmall?.copyWith(color: p.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          PrismCard(
            child: Text(
              streak.days > 0
                  ? 'Continue comme ça — ne brise pas ta série !'
                  : 'La série peut être réparée si tu as assez de gemmes.',
              style: t.bodyMedium?.copyWith(color: p.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _StreakHero extends StatefulWidget {
  const _StreakHero({required this.days});
  final int days;

  @override
  State<_StreakHero> createState() => _StreakHeroState();
}

class _StreakHeroState extends State<_StreakHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
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
    final bool reducedMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget hero = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.local_fire_department_rounded,
          color: p.ember,
          size: 80,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.days}',
          style: t.displayLarge?.copyWith(
            color: p.ember,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          widget.days == 1 ? '1 jour de série' : '${widget.days} jours de série',
          style: t.titleMedium?.copyWith(color: p.textSecondary),
        ),
      ],
    );

    if (reducedMotion) return hero;
    return ScaleTransition(scale: _scale, child: hero);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: t.labelMedium?.copyWith(color: p.textPrimary)),
        ],
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

/// Card that shows the repair cost and lets the learner trigger a repair.
class _RepairCard extends ConsumerStatefulWidget {
  const _RepairCard({required this.costGems, required this.onRepaired});

  final int costGems;
  final VoidCallback onRepaired;

  @override
  ConsumerState<_RepairCard> createState() => _RepairCardState();
}

class _RepairCardState extends ConsumerState<_RepairCard> {
  bool _repairing = false;
  String? _error;

  Future<void> _repair() async {
    setState(() {
      _repairing = true;
      _error = null;
    });
    final Result<RepairStreakResult> result =
        await ref.read(streakRepositoryProvider).repairStreak();
    if (!mounted) return;
    result.when(
      success: (_) {
        setState(() => _repairing = false);
        widget.onRepaired();
      },
      failure: (Failure f) {
        setState(() {
          _repairing = false;
          _error = f.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: p.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.build_rounded, color: p.warning, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Réparer la série', style: t.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tu as manqué hier. Répare ta série maintenant pour ${widget.costGems} 💎.',
            style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.4),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: t.bodySmall?.copyWith(color: p.error),
            ),
          ],
          const SizedBox(height: 16),
          PrismButton(
            label: 'Réparer (${widget.costGems} 💎)',
            icon: Icons.auto_fix_high_rounded,
            loading: _repairing,
            onPressed: _repairing ? null : _repair,
          ),
        ],
      ),
    );
  }
}

class _StreakLoading extends StatelessWidget {
  const _StreakLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: const <Widget>[
        SizedBox(height: 48),
        PrismSkeleton(width: 80, height: 80),
        SizedBox(height: 16),
        PrismSkeleton(width: 120, height: 48),
        SizedBox(height: 8),
        PrismSkeleton(width: 180, height: 20),
        SizedBox(height: 32),
        PrismSkeleton(height: 96),
      ],
    );
  }
}
