import 'dart:math' as math;

import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../application/path_rules.dart';
import 'cert_picker_sheet.dart';

/// Path — the certification map, reimagined as Duolingo's living winding
/// skill-path. Each exam domain is a colored **unit** (header + guardian
/// mascot); each lesson is a bouncing **node** on a serpentine trail, ending in
/// a checkpoint boss. The next action bounces with a call-out and is mirrored by
/// a pinned "CONTINUER" button. Driven by `pathProvider(trackId)` with skeleton
/// loading and a retry error state.
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LearningPath> async = ref.watch(pathProvider(trackId));
    // Resource row reads the shared profile; resilient by design — if the
    // profile is loading or unavailable, the row simply hides (never blocks the
    // path, and keeps widget tests that only stub the path provider green).
    final UserProfile? me = ref.watch(meProvider).asData?.value;

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: async.when(
          data: (LearningPath path) => _PathContent(path: path, trackId: trackId, me: me),
          loading: () => const _PathLoading(),
          error: (Object error, StackTrace _) =>
              PrismStatusView.error(onRetry: () => ref.invalidate(pathProvider(trackId))),
        ),
      ),
    );
  }
}

/// Compact, scrollaway top resource row for the path — streak / gems / XP, the
/// Duolingo-style "your economy at a glance" header.
class _PathResourceBar extends StatelessWidget {
  const _PathResourceBar({required this.me});

  final UserProfile me;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        0,
      ),
      child: Row(
        children: <Widget>[
          StreakBadge(days: me.streakDays, active: me.dailyProgress >= 1),
          const SizedBox(width: 8),
          GemCounter(gems: me.gems),
          const Spacer(),
          XpChip(xp: me.xp),
        ],
      ),
    );
  }
}

/// Plus grande taille Dynamic Type **standard** d'iOS (`xxxLarge`), exprimée en
/// facteur d'échelle. Au-delà commencent les tailles d'**accessibilité**
/// (AX1–AX5, jusqu'à ≈ 3,1×), pour lesquelles un en-tête épinglé confisquerait
/// l'écran : mesuré, afficher en entier un nom de certification de
/// 65 caractères réclame ≈ 294 px à 2×, soit 35 % d'un iPhone 14. Le bandeau
/// défile donc au lieu de rester épinglé — il rend sa place au parcours.
const double _kMaxStandardDynamicType = 1.35;

/// Guardian mascots seated on each unit, cycled by unit index.
const List<AuroraMascot> _guardians = <AuroraMascot>[
  AuroraMascot.nimbus,
  AuroraMascot.volt,
  AuroraMascot.cosmo,
  AuroraMascot.sentinel,
  AuroraMascot.bicky,
  AuroraMascot.pixel,
];

class _PathContent extends StatelessWidget {
  const _PathContent({required this.path, required this.trackId, this.me});

  final LearningPath path;
  final String trackId;
  final UserProfile? me;

  /// Accent for [unit], keyed on its exam domain (falls back to its position).
  Color _accentFor(PrismColorScheme p, PathUnit unit, int unitIndex) {
    final int di = path.domains.indexWhere((DomainProgress d) => d.id == unit.domainId);
    return p.accentFor(di >= 0 ? di : unitIndex);
  }

  /// Same domain accent, in the solid-fill role — for the CTA tone, which
  /// carries white text and must not take the adaptive foreground colour.
  Color _accentFillFor(PrismColorScheme p, PathUnit unit, int unitIndex) {
    final int di = path.domains.indexWhere((DomainProgress d) => d.id == unit.domainId);
    return p.accentFillFor(di >= 0 ? di : unitIndex);
  }

  void _openLesson(BuildContext context, String lessonId) => context.go(
        '${Routes.lesson}/${Uri.encodeComponent(trackId)}/${Uri.encodeComponent(lessonId)}',
      );

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;

    // The learner's single "next action" across the whole path — the first
    // actionable lesson in order. Shared with Home through [currentLessonIdOf]
    // so both screens agree on what "continue" means. Drives the bouncing node
    // call-out and the pinned CTA.
    final String? activeId = currentLessonIdOf(path);
    PathLesson? active;
    bool activeInProgress = false;
    if (activeId != null) {
      for (final PathUnit u in path.units) {
        for (final PathLesson l in u.lessons) {
          if (l.id == activeId) {
            active = l;
            activeInProgress = l.status == NodeStatus.inProgress;
            break;
          }
        }
        if (active != null) break;
      }
    }

    Color ctaAccent = p.primaryFill;
    int chapterIndex = 0;
    if (active != null) {
      for (int i = 0; i < path.units.length; i++) {
        if (path.units[i].lessons.any((PathLesson l) => l.id == active!.id)) {
          ctaAccent = _accentFillFor(p, path.units[i], i);
          chapterIndex = i;
          break;
        }
      }
    }
    final String chapterLabel = path.units.isEmpty
        ? ''
        : 'Chapitre ${chapterIndex + 1} · ${path.units[chapterIndex].title}';

    int running = 0; // continuous sine phase across units for one flowing trail
    final List<Widget> slivers = <Widget>[
      if (me != null) SliverToBoxAdapter(child: _PathResourceBar(me: me!)),
      // Le bandeau se dimensionne sur son contenu. Épinglé aux tailles Dynamic
      // Type **standard**, il défile aux tailles d'**accessibilité** : mesuré,
      // afficher en entier un nom de 65 caractères réclame 294 px à 2×, soit
      // 35 % d'un iPhone 14 — un en-tête épinglé de cette taille confisquerait
      // l'écran au lieu de servir le contenu.
      if (MediaQuery.textScalerOf(context).scale(1) <= _kMaxStandardDynamicType)
        PinnedHeaderSliver(
          child: _PathBanner(
            trackName: path.trackName,
            exam: path.exam,
            chapterLabel: chapterLabel,
            score: path.readinessScore,
            trend: path.readinessTrend7d,
            onTapTitle: () => showCertPickerSheet(context),
          ),
        )
      else
        SliverToBoxAdapter(
          child: _PathBanner(
            trackName: path.trackName,
            exam: path.exam,
            chapterLabel: chapterLabel,
            score: path.readinessScore,
            trend: path.readinessTrend7d,
            onTapTitle: () => showCertPickerSheet(context),
          ),
        ),
      // Le CTA reste épinglé à TOUTES les échelles : c'est l'action primaire,
      // et « Dynamic Type maximal ne masque aucune action ».
      if (active != null)
        PinnedHeaderSliver(
          child: _ContinueCta(
            label: activeInProgress ? 'Continuer' : 'Commencer',
            accent: ctaAccent,
            onTap: () => _openLesson(context, active!.id),
          ),
        ),
    ];

    for (int i = 0; i < path.units.length; i++) {
      final PathUnit u = path.units[i];
      final Color accent = _accentFor(p, u, i);
      final AuroraMascot guardian = _guardians[i % _guardians.length];
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.md,
            PrismSpacing.gutter,
            PrismSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: UnitHeader(
              index: i + 1,
              title: u.title,
              accent: accent,
              domainName: _domainName(u.domainId),
              mascot: guardian,
              completed: u.completedCount,
              total: u.lessons.length,
            ),
          ),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: _UnitTrail(
            unit: u,
            accent: accent,
            guardian: guardian,
            startPhase: running,
            activeLessonId: active?.id,
            activeInProgress: activeInProgress,
            onLesson: (String id) => _openLesson(context, id),
          ),
        ),
      );
      running += u.lessons.length + 1; // +1 for the unit checkpoint node
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));

    return CustomScrollView(slivers: slivers);
  }

  String? _domainName(String domainId) {
    final int i = path.domains.indexWhere((DomainProgress d) => d.id == domainId);
    return i >= 0 ? path.domains[i].name : null;
  }
}

/// One unit's serpentine trail: lesson bubbles on a sine path, a connector line
/// threading their centers, then a checkpoint boss guarded by the unit mascot.
class _UnitTrail extends StatelessWidget {
  const _UnitTrail({
    required this.unit,
    required this.accent,
    required this.guardian,
    required this.startPhase,
    required this.activeLessonId,
    required this.activeInProgress,
    required this.onLesson,
  });

  final PathUnit unit;
  final Color accent;
  final AuroraMascot guardian;
  final int startPhase;
  final String? activeLessonId;
  final bool activeInProgress;
  final ValueChanged<String> onLesson;

  static const double _rowH = 124;
  static const double _nodeSize = 64;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final int count = unit.lessons.length + 1; // +1 checkpoint
    final double height = count * _rowH + 12;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double width = c.maxWidth;
        final double amp = (width * 0.26).clamp(40.0, 92.0);

        double centerX(int i) {
          final double x = width / 2 + amp * math.sin((startPhase + i) * 0.9);
          return x.clamp(_nodeSize / 2 + 10, width - _nodeSize / 2 - 10);
        }

        double centerY(int i) => i * _rowH + _nodeSize / 2 + 8;

        // Node statuses in trail order (lessons then checkpoint) for the
        // connector: a segment is "earned" when both ends are done.
        final PathNodeStatus checkpoint = _toNodeStatus(gateStatusOf(unit));
        final List<PathNodeStatus> statuses = <PathNodeStatus>[
          for (final PathLesson l in unit.lessons) _toNodeStatus(l.status),
          checkpoint,
        ];
        final List<Offset> centers = <Offset>[
          for (int i = 0; i < count; i++) Offset(centerX(i), centerY(i)),
        ];
        bool earned(PathNodeStatus s) =>
            s == PathNodeStatus.completed || s == PathNodeStatus.mastered;
        final List<bool> seg = <bool>[
          for (int i = 0; i < count - 1; i++) earned(statuses[i]) && earned(statuses[i + 1]),
        ];

        final List<Widget> children = <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _TrailConnector(
                centers: centers,
                earned: seg,
                accent: accent,
                idle: p.border,
              ),
            ),
          ),
        ];

        for (int i = 0; i < unit.lessons.length; i++) {
          final PathLesson l = unit.lessons[i];
          final bool isActive = l.id == activeLessonId;
          children.add(
            Positioned(
              left: centers[i].dx - _nodeSize / 2,
              top: centers[i].dy - _nodeSize / 2,
              child: PathNode(
                status: _toNodeStatus(l.status),
                accent: accent,
                label: l.title,
                progress: l.masteryPct / 100,
                current: isActive,
                startLabel: isActive ? (activeInProgress ? 'Reprendre' : 'Commencer') : null,
                onTap: () => onLesson(l.id),
              ),
            ),
          );
        }

        // Checkpoint boss + its guardian mascot, side-seated on the trail.
        final int ci = count - 1;
        final String? gateLessonId = gateCheckpointLessonId(unit);
        final bool gateOpen = gateLessonId != null;
        children.add(
          Positioned(
            left: centers[ci].dx - _nodeSize / 2,
            top: centers[ci].dy - _nodeSize / 2,
            child: PathNode(
              status: checkpoint,
              kind: PathNodeKind.checkpoint,
              accent: accent,
              label: 'Révision',
              onTap: gateLessonId == null ? null : () => onLesson(gateLessonId),
            ),
          ),
        );
        final bool guardLeft = centers[ci].dx > width / 2;
        final double guardLeftPos = guardLeft
            ? (centers[ci].dx - _nodeSize / 2 - 52 - 10)
            : (centers[ci].dx + _nodeSize / 2 + 10);
        children.add(
          Positioned(
            left: guardLeftPos.clamp(8.0, width - 60),
            top: centers[ci].dy - 26,
            child: MascotAvatar(
              mascot: guardian,
              size: 52,
              mood: gateOpen ? MascotMood.happy : MascotMood.idle,
            ),
          ),
        );

        return SizedBox(
          height: height,
          width: width,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

/// Banner that keeps the active certification and current chapter in view while
/// the long path scrolls beneath it. Tapping the title opens the course picker
/// so the learner can switch certifications, Duolingo-style.
///
/// Il **se dimensionne sur son contenu** au lieu d'imposer une hauteur fixe.
/// L'ancienne valeur figée de 88 px débordait de 2 px dès 1,5× de Dynamic Type
/// et de 23 px à 2×. Le nom de certification reflue désormais librement : borné
/// à une ligne, il rendait « Microsoft Certified: Az… » sur 221 px pour les
/// 65 caractères de « Microsoft Certified: Azure AI Apps and Agents Developer
/// Associate » — c'est-à-dire le préfixe commun à *toutes* les certifications
/// Microsoft, qui n'en distingue donc aucune.
class _PathBanner extends StatelessWidget {
  const _PathBanner({
    required this.trackName,
    required this.exam,
    required this.chapterLabel,
    required this.score,
    required this.trend,
    required this.onTapTitle,
  });

  final String trackName;
  final String exam;
  final String chapterLabel;
  final int score;
  final int trend;
  final VoidCallback onTapTitle;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      color: p.background,
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        PrismSpacing.debt10,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Le nom occupe la **pleine largeur**. Coincé dans la colonne de
            // 221 px que lui laissait la puce de readiness, il réclamait 7
            // lignes (168 px) à 1× et 784 px à 2× : lui rendre la largeur le
            // ramène à deux lignes, où les 65 caractères tiennent en entier.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapTitle,
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      trackName,
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, size: 22, color: p.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // `Wrap` plutôt que `Row` : pastille d'examen, readiness et
            // chapitre restent côte à côte tant que la place existe, et le
            // chapitre bascule sur sa propre ligne pleine largeur sinon.
            // Mesuré à 2× : la `Row` n'accordait que 34,8 px au chapitre pour
            // 57 caractères — il ne restait rien à lire.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: PrismSpacing.xs,
              runSpacing: 4,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PrismSpacing.debt9,
                    vertical: PrismSpacing.debt3,
                  ),
                  decoration: BoxDecoration(
                    color: p.primarySoft,
                    borderRadius: PrismRadii.pillAll,
                  ),
                  child: Text(
                    exam,
                    style: t.labelSmall?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                _ReadinessChip(score: score, trend: trend),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth),
                  child: Text(
                    chapterLabel,
                    style: t.bodySmall?.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned, full-width "next action" button mirroring the bouncing trail node.
///
/// Se dimensionne sur son contenu : sa hauteur figée de 78 px ne survivait pas
/// aux tailles Dynamic Type d'accessibilité. Il reste épinglé à **toutes** les
/// échelles, parce que c'est l'action primaire de l'écran.
class _ContinueCta extends StatelessWidget {
  const _ContinueCta({required this.label, required this.accent, required this.onTap});

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Container(
      color: p.background,
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.debt10,
        PrismSpacing.gutter,
        PrismSpacing.debt14,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: PrismMotion.resolve(context, PrismMotion.fast),
        reverseDuration: PrismMotion.resolve(context, PrismMotion.instant),
        switchInCurve: PrismMotion.spring,
        switchOutCurve: PrismMotion.standard,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
          return FadeTransition(
            opacity: animation,
            child: reduceMotion ? child : ScaleTransition(scale: animation, child: child),
          );
        },
        child: PrismButton(
          key: ValueKey<String>('cta-$label-${accent.value}'),
          label: label,
          icon: Icons.play_arrow_rounded,
          tone: accent,
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({required this.score, required this.trend});

  final int score;
  final int trend;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool up = trend >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.sm,
        vertical: PrismSpacing.debt7,
      ),
      decoration: BoxDecoration(color: p.primarySoft, borderRadius: PrismRadii.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.insights_rounded, size: 16, color: p.primary),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: PrismTypography.tabular(
              TextStyle(color: p.primary, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 15,
            color: up ? p.success : p.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _TrailConnector extends CustomPainter {
  _TrailConnector({
    required this.centers,
    required this.earned,
    required this.accent,
    required this.idle,
  });

  final List<Offset> centers;
  final List<bool> earned;
  final Color accent;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < centers.length - 1; i++) {
      final Paint paint = Paint()
        ..color = (earned[i] ? accent : idle).withOpacity(earned[i] ? 0.9 : 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(centers[i], centers[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_TrailConnector old) =>
      old.centers != centers || old.earned != earned || old.accent != accent;
}

class _PathLoading extends StatelessWidget {
  const _PathLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
      children: const <Widget>[
        PrismSkeleton(width: 120, height: 14),
        SizedBox(height: 10),
        PrismSkeleton(width: 240, height: 28),
        SizedBox(height: 20),
        PrismSkeleton(height: 120),
        SizedBox(height: 16),
        PrismSkeleton(height: 150),
        SizedBox(height: 16),
        PrismSkeleton(height: 110),
      ],
    );
  }
}

PathNodeStatus _toNodeStatus(NodeStatus s) {
  return switch (s) {
    NodeStatus.mastered => PathNodeStatus.mastered,
    NodeStatus.completed => PathNodeStatus.completed,
    NodeStatus.inProgress => PathNodeStatus.inProgress,
    NodeStatus.available => PathNodeStatus.available,
    NodeStatus.locked => PathNodeStatus.locked,
  };
}
