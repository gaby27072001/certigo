import 'dart:async';

import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../shared/errors/error_copy.dart';

/// Third level of the catalogue: the chapters (units) of one certification,
/// rendered as a Duolingo "section picker".
///
/// Reads the real [LearningPath] from `pathProvider(trackId)` and stacks a
/// [ChapterSectionCard] per unit with the *actual* lock/progress state, a mascot
/// guardian intercalated every few chapters and a readiness header. Tapping an
/// unlocked chapter points [activeTrackProvider] at this track and jumps to the
/// Path tab.
class CertificationChaptersScreen extends ConsumerWidget {
  const CertificationChaptersScreen({super.key, required this.trackId});

  final String trackId;

  /// Aurora Crew guardians cycled through the intercalated mascot bubbles.
  static const List<AuroraMascot> _guardians = <AuroraMascot>[
    AuroraMascot.nimbus,
    AuroraMascot.pip,
    AuroraMascot.volt,
    AuroraMascot.cosmo,
    AuroraMascot.sentinel,
  ];

  static const List<String> _cheers = <String>[
    'Continue comme ça, chaque chapitre te rapproche de l\'examen !',
    'Ce chapitre pèse lourd le jour J — prends ton temps.',
    'Bien joué ! On enchaîne sur la suite ?',
    'Un pas de plus vers ta certification. 💪',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LearningPath> path = ref.watch(pathProvider(trackId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapitres', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        top: false,
        child: path.when(
          data: (LearningPath data) => _buildList(context, ref, data),
          loading: () => const _LoadingList(),
          error: (Object err, StackTrace __) => _ErrorView(
            copy: describeFailure(err, subject: ErrorSubject.chapters),
            onRetry: () => ref.invalidate(pathProvider(trackId)),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, LearningPath path) {
    if (path.units.isEmpty) {
      return const _EmptyView();
    }

    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.md),
      children: <Widget>[
        _PathHeader(path: path),
        const SizedBox(height: PrismSpacing.lg),
        for (int i = 0; i < path.units.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: PrismSpacing.md),
            child: _chapterCard(context, ref, path.units[i], i),
          ),
      ],
    );
  }

  Widget _chapterCard(BuildContext context, WidgetRef ref, PathUnit unit, int index) {
    final bool locked = unit.status == NodeStatus.locked;
    final bool completed =
        unit.status == NodeStatus.completed || unit.status == NodeStatus.mastered;
    final Color accent = context.prism.accentFor(index);

    // A guardian peeks in above every third chapter to keep the shelf lively.
    final bool showMascot = index > 0 && index % 3 == 0;

    return ChapterSectionCard(
      index: index + 1,
      title: unit.title,
      accent: accent,
      lessonsTotal: unit.lessons.length,
      lessonsCompleted: unit.completedCount,
      locked: locked,
      completed: completed,
      lockedHint: 'Termine le chapitre précédent pour débloquer',
      onStart: locked ? null : () => _openChapter(context, ref),
      mascot: showMascot ? _guardians[index % _guardians.length] : null,
      mascotMessage: showMascot ? _cheers[index % _cheers.length] : null,
    );
  }

  /// Points the Path tab at this track and jumps to it — the "démarrer /
  /// continuer cette certif" action.
  Future<void> _openChapter(BuildContext context, WidgetRef ref) async {
    final ActiveTrackSaveResult result =
        await ref.read(activeTrackProvider.notifier).select(trackId);
    if (!context.mounted) return;
    if (result.accepted) {
      context.go(Routes.path);
      return;
    }
    // Canal : changer de certification est une action volontaire et isolée. Son
    // échec ne casse aucun flux en cours — l'apprenant reste où il est. Un
    // toast est le bon niveau ; une alerte pleine page serait disproportionnée.
    // Il dit quand même la cause, et rend l'action refaisable d'un geste.
    final ErrorCopy copy = describeFailure(result.failure, subject: ErrorSubject.chapters);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ta certification n\'a pas changé. ${copy.title}.'),
        action: SnackBarAction(
          label: 'Réessayer',
          onPressed: () => unawaited(_openChapter(context, ref)),
        ),
      ),
    );
  }
}

/// Header card: exam code, title and the track Readiness Score.
class _PathHeader extends StatelessWidget {
  const _PathHeader({required this.path});

  final LearningPath path;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: p.primary,
      elevation: 0,
      padding: const EdgeInsets.all(PrismSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PrismSpacing.sm,
                  vertical: PrismSpacing.xxs,
                ),
                decoration: BoxDecoration(color: p.primary, borderRadius: PrismRadii.pillAll),
                child: Text(
                  path.exam,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.workspace_premium_rounded, size: 18, color: p.primary),
              const SizedBox(width: PrismSpacing.xxs),
              Text(
                'Readiness ${path.readinessScore}%',
                style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: p.primary),
              ),
            ],
          ),
          const SizedBox(height: PrismSpacing.sm),
          Text(path.trackName, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: PrismSpacing.sm),
          PrismProgressBar(
            value: (path.readinessScore / 100).clamp(0.0, 1.0),
            semanticLabel: 'Readiness de la certification',
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.md),
      children: const <Widget>[
        PrismSkeleton(height: 96),
        SizedBox(height: PrismSpacing.lg),
        PrismSkeleton(height: 120),
        SizedBox(height: PrismSpacing.md),
        PrismSkeleton(height: 120),
        SizedBox(height: PrismSpacing.md),
        PrismSkeleton(height: 120),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PrismSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MascotAvatar(mascot: AuroraMascot.pip, size: 72),
            const SizedBox(height: PrismSpacing.md),
            Text(
              'Aucun chapitre disponible pour cette certification.',
              textAlign: TextAlign.center,
              style: t.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.copy, required this.onRetry});

  final ErrorCopy copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool canRetry = copy.retryResolves;
    return PrismStatusView(
      icon: copy.icon,
      title: copy.title,
      message: copy.message,
      actionLabel: copy.actionLabel,
      actionIcon: copy.actionIcon,
      onAction: canRetry ? onRetry : () => Navigator.of(context).maybePop(),
    );
  }
}
