import 'dart:math' as math;

import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';

/// Path — the Duolingo-style certification journey.
///
/// Instead of a flat list of cards, the track is rendered as a vertical
/// *winding trail* of circular lesson nodes grouped into chapters (units).
/// Each node encodes its [NodeStatus] (locked / available / in progress /
/// completed / mastered) with a pressable 3D button look, the next lesson to
/// do gets an animated "COMMENCER" call-to-action, and every chapter ends with
/// a **validation checkpoint** that only opens once all its lessons are done.
///
/// Driven by `pathProvider(trackId)` with skeleton loading and a retry error
/// state. Lesson navigation is unchanged (`/lesson/:trackId/:lessonId`).
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LearningPath> async = ref.watch(pathProvider(trackId));

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: async.when(
          data: (LearningPath path) => _PathJourney(path: path, trackId: trackId),
          loading: () => const _PathLoading(),
          error: (Object error, StackTrace _) => PrismStatusView.error(
            onRetry: () => ref.invalidate(pathProvider(trackId)),
          ),
        ),
      ),
    );
  }
}

/// The winding journey: a compact header followed by chapter banners and their
/// serpentine lesson nodes + validation checkpoints.
class _PathJourney extends StatelessWidget {
  const _PathJourney({required this.path, required this.trackId});

  final LearningPath path;
  final String trackId;

  /// Maps a unit's domainId to its index in [LearningPath.domains] so each
  /// chapter gets a stable, distinct accent from the Prism palette.
  int _accentIndex(int unitIndex) {
    final PathUnit unit = path.units[unitIndex];
    final int byDomain = path.domains.indexWhere((DomainProgress d) => d.id == unit.domainId);
    return byDomain >= 0 ? byDomain : unitIndex;
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // The single "next thing to do" across the whole track — gets the CTA.
    final String? currentLessonId = _firstActionableLessonId(path);

    final List<Widget> journey = <Widget>[];
    int step = 0; // running node counter → continuous serpentine wander.

    for (int i = 0; i < path.units.length; i++) {
      final PathUnit unit = path.units[i];
      final Color accent = p.accentFor(_accentIndex(i));

      journey.add(_ChapterBanner(index: i + 1, unit: unit, accent: accent));

      for (final PathLesson lesson in unit.lessons) {
        final double dx = math.sin(step * 0.8) * 0.62;
        step++;
        journey.add(
          _NodeRow(
            dx: dx,
            child: _LessonNode(
              lesson: lesson,
              accent: accent,
              isCurrent: lesson.id == currentLessonId,
              reduceMotion: reduceMotion,
              onTap: () => context.go('${Routes.lesson}/$trackId/${lesson.id}'),
            ),
          ),
        );
      }

      // Each chapter closes on its validation checkpoint (always centered).
      step++;
      journey.add(
        _NodeRow(
          dx: 0,
          child: _CheckpointNode(
            unit: unit,
            accent: accent,
            onReview: unit.lessons.isEmpty
                ? null
                : () => context.go('${Routes.lesson}/$trackId/${unit.lessons.first.id}'),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _JourneyHeader(path: path)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 140),
          sliver: SliverList(delegate: SliverChildListDelegate(journey)),
        ),
      ],
    );
  }
}

/// First lesson on the path that is ready to be played (available or resumed).
String? _firstActionableLessonId(LearningPath path) {
  for (final PathUnit unit in path.units) {
    for (final PathLesson lesson in unit.lessons) {
      if (lesson.status == NodeStatus.available || lesson.status == NodeStatus.inProgress) {
        return lesson.id;
      }
    }
  }
  return null;
}

/// Compact track header: name, exam code and a live readiness pill.
class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({required this.path});

  final LearningPath path;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool up = path.readinessTrend7d >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Parcours', style: t.bodyMedium?.copyWith(color: p.textSecondary)),
                Text(path.trackName, style: t.headlineSmall),
                Text(path.exam, style: t.labelLarge?.copyWith(color: p.primary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GlassSurface(
            borderRadius: PrismRadii.pillAll,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.bolt_rounded, size: 16, color: p.xpGold),
                    const SizedBox(width: 4),
                    Text(
                      '${path.readinessScore}%',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 13,
                      color: up ? p.success : p.error,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Prêt·e — 7j ${up ? '+' : ''}${path.readinessTrend7d}',
                      style: t.labelSmall?.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "SECTION / CHAPITRE" banner that introduces a unit, colored by its
/// domain accent with a pressable 3D base — Duolingo's chapter header.
class _ChapterBanner extends StatelessWidget {
  const _ChapterBanner({required this.index, required this.unit, required this.accent});

  final int index;
  final PathUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final int total = unit.lessons.length;
    final int done = unit.completedCount;

    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: PrismRadii.cardLg,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _shade(accent, 0.28),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'CHAPITRE $index',
                    style: t.labelMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unit.title,
                    style: t.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (total > 0) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      '$done / $total leçons',
                      style: t.labelSmall?.copyWith(color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              done >= total && total > 0 ? Icons.menu_book_rounded : Icons.auto_stories_outlined,
              color: Colors.white,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

/// Positions a node along the winding trail at horizontal alignment [dx]
/// (-1 = left edge, 0 = center, 1 = right edge).
class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.dx, required this.child});

  final double dx;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(alignment: Alignment(dx, 0), child: child),
    );
  }
}

/// A single circular lesson node on the trail with a 3D pressable look. The
/// next actionable lesson ([isCurrent]) gets a pulsing halo and a bobbing
/// "COMMENCER" bubble.
class _LessonNode extends StatelessWidget {
  const _LessonNode({
    required this.lesson,
    required this.accent,
    required this.isCurrent,
    required this.reduceMotion,
    required this.onTap,
  });

  final PathLesson lesson;
  final Color accent;
  final bool isCurrent;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool locked = lesson.status == NodeStatus.locked;
    final _NodeVisual v = _visualFor(lesson.status, accent, p);

    final Widget core = _NodeCircle(
      top: v.top,
      base: v.base,
      icon: v.icon,
      iconColor: v.iconColor,
      progress: lesson.status == NodeStatus.inProgress ? lesson.masteryPct / 100 : null,
      ringColor: accent,
    );

    final Widget node = Semantics(
      button: !locked,
      enabled: !locked,
      label: '${lesson.title} — ${_statusLabel(lesson.status)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onTap,
        child: Opacity(opacity: locked ? 0.65 : 1, child: core),
      ),
    );

    if (!isCurrent) {
      return node;
    }
    return _ActiveNodeDecoration(accent: accent, reduceMotion: reduceMotion, child: node);
  }
}

/// The end-of-chapter validation gate. Locked until every lesson in the unit is
/// completed; turns into a celebratory, tappable trophy once the chapter is
/// validated (and gold once mastered).
class _CheckpointNode extends StatelessWidget {
  const _CheckpointNode({required this.unit, required this.accent, required this.onReview});

  final PathUnit unit;
  final Color accent;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    final bool mastered = unit.status == NodeStatus.mastered;
    final bool validated = unit.lessons.isNotEmpty && unit.completedCount == unit.lessons.length;
    final bool unlocked = mastered || validated;

    final Color top = mastered ? p.xpGold : (validated ? p.success : p.surfaceAlt);
    final Color base = _shade(top, mastered || validated ? 0.28 : 0.0);
    final IconData icon = mastered
        ? Icons.workspace_premium_rounded
        : (validated ? Icons.emoji_events_rounded : Icons.flag_rounded);
    final Color iconColor = unlocked ? Colors.white : p.textSecondary;

    final String label =
        mastered ? 'Chapitre maîtrisé' : (validated ? 'Chapitre validé' : 'Validation du chapitre');
    final String sub =
        unlocked ? 'Révision disponible' : '${unit.completedCount}/${unit.lessons.length} leçons';

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Semantics(
        button: unlocked,
        enabled: unlocked,
        label: '$label — $sub',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: unlocked ? onReview : null,
          child: Opacity(
            opacity: unlocked ? 1 : 0.7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _NodeCircle(
                  top: top,
                  base: unlocked ? base : p.border,
                  icon: icon,
                  iconColor: iconColor,
                  size: 88,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: t.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: mastered ? p.xpGold : (validated ? p.success : p.textSecondary),
                  ),
                ),
                Text(sub, style: t.labelSmall?.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacked two-circle button giving the signature pressable 3D depth: a darker
/// [base] disc behind a lighter [top] disc that carries the [icon]. Optionally
/// draws a [progress] ring for in-progress lessons.
class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.top,
    required this.base,
    required this.icon,
    required this.iconColor,
    this.size = 72,
    this.progress,
    this.ringColor,
  });

  final Color top;
  final Color base;
  final IconData icon;
  final Color iconColor;
  final double size;
  final double? progress;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    const double depth = 7;
    final Widget stacked = SizedBox(
      width: size,
      height: size + depth,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: size,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: top, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: size * 0.46),
            ),
          ),
        ],
      ),
    );

    if (progress == null) {
      return stacked;
    }
    return SizedBox(
      width: size + 14,
      height: size + depth + 14,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned(
            top: 0,
            child: SizedBox(
              width: size + 12,
              height: size + 12,
              child: CircularProgressIndicator(
                value: progress!.clamp(0, 1),
                strokeWidth: 5,
                backgroundColor: (ringColor ?? top).withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(ringColor ?? top),
              ),
            ),
          ),
          Positioned(top: 6, child: stacked),
        ],
      ),
    );
  }
}

/// Wraps the active lesson node with a bobbing "COMMENCER" bubble and a pulsing
/// halo. Animation is skipped when the platform requests reduced motion.
class _ActiveNodeDecoration extends StatefulWidget {
  const _ActiveNodeDecoration({
    required this.child,
    required this.accent,
    required this.reduceMotion,
  });

  final Widget child;
  final Color accent;
  final bool reduceMotion;

  @override
  State<_ActiveNodeDecoration> createState() => _ActiveNodeDecorationState();
}

class _ActiveNodeDecorationState extends State<_ActiveNodeDecoration>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    // Only spin up a ticker when motion is allowed. Constructing the controller
    // unconditionally would register a TickerMode dependency even in
    // reduced-motion / test environments, which leaks on teardown.
    if (!widget.reduceMotion) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final AnimationController? c = _c;
    if (c == null) {
      return _content(p, 0);
    }
    return AnimatedBuilder(
      animation: c,
      builder: (BuildContext context, Widget? child) => _content(p, c.value),
    );
  }

  Widget _content(PrismColorScheme p, double v) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Transform.translate(
          offset: Offset(0, -4 * v),
          child: _StartBubble(accent: widget.accent, surface: p.surface),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.scale(
              scale: 1 + 0.28 * v,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent.withOpacity(0.30 * (1 - v)),
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ],
    );
  }
}

/// A small "COMMENCER" speech bubble with a downward tail.
class _StartBubble extends StatelessWidget {
  const _StartBubble({required this.accent, required this.surface});

  final Color accent;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: PrismRadii.pillAll,
            border: Border.all(color: accent, width: 2),
          ),
          child: Text(
            'COMMENCER',
            style: t.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ),
        CustomPaint(size: const Size(16, 8), painter: _TailPainter(surface, accent)),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.fill, this.stroke);

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => false;
}

class _NodeVisual {
  const _NodeVisual(this.top, this.base, this.icon, this.iconColor);

  final Color top;
  final Color base;
  final IconData icon;
  final Color iconColor;
}

_NodeVisual _visualFor(NodeStatus status, Color accent, PrismColorScheme p) {
  return switch (status) {
    NodeStatus.mastered => _NodeVisual(
        p.xpGold,
        _shade(p.xpGold, 0.28),
        Icons.workspace_premium_rounded,
        Colors.white,
      ),
    NodeStatus.completed => _NodeVisual(
        p.success,
        _shade(p.success, 0.28),
        Icons.check_rounded,
        Colors.white,
      ),
    NodeStatus.inProgress => _NodeVisual(
        accent,
        _shade(accent, 0.28),
        Icons.star_half_rounded,
        Colors.white,
      ),
    NodeStatus.available => _NodeVisual(
        accent,
        _shade(accent, 0.28),
        Icons.star_rounded,
        Colors.white,
      ),
    NodeStatus.locked => _NodeVisual(
        p.surfaceAlt,
        p.border,
        Icons.lock_rounded,
        p.textSecondary,
      ),
  };
}

String _statusLabel(NodeStatus status) {
  return switch (status) {
    NodeStatus.mastered => 'maîtrisée',
    NodeStatus.completed => 'terminée',
    NodeStatus.inProgress => 'en cours',
    NodeStatus.available => 'disponible',
    NodeStatus.locked => 'verrouillée',
  };
}

/// Darkens [c] toward black by [amount] (0–1) for the 3D base discs.
Color _shade(Color c, double amount) => Color.lerp(c, Colors.black, amount) ?? c;

class _PathLoading extends StatelessWidget {
  const _PathLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: const <Widget>[
        PrismSkeleton(width: 160, height: 28),
        SizedBox(height: 20),
        PrismSkeleton(height: 72),
        SizedBox(height: 28),
        Center(child: PrismSkeleton(width: 72, height: 72)),
        SizedBox(height: 20),
        Center(child: PrismSkeleton(width: 72, height: 72)),
        SizedBox(height: 20),
        Center(child: PrismSkeleton(width: 72, height: 72)),
      ],
    );
  }
}
