import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';

/// Path — the certification map. Shows the track's readiness, exam-domain
/// breakdown, and an ordered list of units with their lesson nodes (locked /
/// available / in progress / completed / mastered). Driven by
/// `pathProvider(trackId)` with skeleton loading and a retry error state.
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
          data: (LearningPath path) => _PathContent(path: path, trackId: trackId),
          loading: () => const _PathLoading(),
          error: (Object error, StackTrace _) => PrismStatusView.error(
            onRetry: () => ref.invalidate(pathProvider(trackId)),
          ),
        ),
      ),
    );
  }
}

class _PathContent extends StatelessWidget {
  const _PathContent({required this.path, required this.trackId});

  final LearningPath path;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Parcours', style: t.bodyMedium?.copyWith(color: p.textSecondary)),
                Text(path.trackName, style: t.headlineMedium),
                Text(path.exam, style: t.labelLarge?.copyWith(color: p.primary)),
                const SizedBox(height: 16),
                if (path.domains.isNotEmpty) _DomainBar(domains: path.domains),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          sliver: SliverList.separated(
            itemCount: path.units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (BuildContext context, int i) {
              final PathUnit u = path.units[i];
              return _UnitCard(
                index: i + 1,
                unit: u,
                onLesson: (String lessonId) => context.go('${Routes.lesson}/$trackId/$lessonId'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DomainBar extends StatelessWidget {
  const _DomainBar({required this.domains});

  final List<DomainProgress> domains;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < domains.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 130,
                    child: Text(
                      domains[i].name,
                      style: t.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: PrismProgressBar(
                      value: (domains[i].score / 100).clamp(0, 1).toDouble(),
                      height: 8,
                      gradient: <Color>[p.accentFor(i), p.accentFor(i)],
                      semanticLabel: domains[i].name,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${domains[i].score}',
                    style: t.labelMedium?.copyWith(color: p.textPrimary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.index, required this.unit, required this.onLesson});

  final int index;
  final PathUnit unit;
  final ValueChanged<String> onLesson;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  borderRadius: PrismRadii.cardSm,
                ),
                child: Text(
                  '$index',
                  style: t.labelLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(unit.title, style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          for (final PathLesson n in unit.lessons)
            LessonTile(
              title: n.title,
              status: _toTileStatus(n.status),
              minutes: n.estMinutes,
              onTap: () => onLesson(n.id),
            ),
        ],
      ),
    );
  }
}

class _PathLoading extends StatelessWidget {
  const _PathLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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

LessonTileStatus _toTileStatus(NodeStatus s) {
  return switch (s) {
    NodeStatus.mastered => LessonTileStatus.mastered,
    NodeStatus.completed => LessonTileStatus.completed,
    NodeStatus.inProgress => LessonTileStatus.inProgress,
    NodeStatus.available => LessonTileStatus.available,
    NodeStatus.locked => LessonTileStatus.locked,
  };
}
