import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/router.dart';

/// Path — the certification map. Shows the track's readiness, exam-domain
/// breakdown, and an ordered list of units with their lesson nodes (locked /
/// available / completed / mastered). Skeleton uses sample structure; wire to
/// `pathRepositoryProvider.getPath(trackId)` in P1.
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key, required this.trackId});

  final String trackId;

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Parcours', style: t.bodyMedium?.copyWith(color: p.textSecondary)),
                    Text('Microsoft Azure Fundamentals', style: t.headlineMedium),
                    Text('AZ-900', style: t.labelLarge?.copyWith(color: p.primary)),
                    const SizedBox(height: 16),
                    _DomainBar(domains: _sampleDomains(p)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              sliver: SliverList.separated(
                itemCount: _sampleUnits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (BuildContext context, int i) {
                  final _Unit u = _sampleUnits[i];
                  return _UnitCard(
                    index: i + 1,
                    unit: u,
                    onLesson: (String lessonId) =>
                        context.go('${Routes.lesson}/$trackId/$lessonId'),
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

class _DomainBar extends StatelessWidget {
  const _DomainBar({required this.domains});
  final List<_Domain> domains;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return GlassSurface(
      child: Column(
        children: <Widget>[
          for (final _Domain d in domains)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 130,
                    child: Text(d.name, style: t.bodySmall, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: PrismProgressBar(
                      value: d.score / 100,
                      height: 8,
                      gradient: <Color>[d.color, d.color],
                      semanticLabel: d.name,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${d.score}', style: t.labelMedium?.copyWith(color: p.textPrimary)),
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
  final _Unit unit;
  final ValueChanged<String> onLesson;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return GlassSurface(
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
                child: Text('$index',
                    style: t.labelLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(unit.title, style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          for (final _LessonNode n in unit.lessons)
            LessonTile(
              title: n.title,
              status: _toTileStatus(n.status),
              minutes: n.minutes,
              onTap: () => onLesson(n.id),
            ),
        ],
      ),
    );
  }
}

// --- Sample structure (replaced by API data in P1) -------------------------

enum _NodeStatus { locked, available, completed, mastered }

LessonTileStatus _toTileStatus(_NodeStatus s) {
  return switch (s) {
    _NodeStatus.mastered => LessonTileStatus.mastered,
    _NodeStatus.completed => LessonTileStatus.completed,
    _NodeStatus.available => LessonTileStatus.available,
    _NodeStatus.locked => LessonTileStatus.locked,
  };
}

class _LessonNode {
  const _LessonNode(this.id, this.title, this.minutes, this.status);
  final String id;
  final String title;
  final int minutes;
  final _NodeStatus status;
}

class _Unit {
  const _Unit(this.title, this.lessons);
  final String title;
  final List<_LessonNode> lessons;
}

class _Domain {
  const _Domain(this.name, this.score, this.color);
  final String name;
  final int score;
  final Color color;
}

List<_Domain> _sampleDomains(PrismColorScheme p) => <_Domain>[
      _Domain('Concepts du cloud', 78, p.accentFor(0)),
      _Domain('Architecture & services', 54, p.accentFor(1)),
      _Domain('Gestion & gouvernance', 41, p.accentFor(2)),
    ];

const List<_Unit> _sampleUnits = <_Unit>[
  _Unit('Concepts du cloud', <_LessonNode>[
    _LessonNode('az900-l-capex-opex', 'Capex vs Opex', 4, _NodeStatus.mastered),
    _LessonNode('az900-l-shared-resp', 'Responsabilité partagée', 5, _NodeStatus.completed),
    _LessonNode('az900-l-cloud-models', 'IaaS / PaaS / SaaS', 6, _NodeStatus.available),
  ]),
  _Unit('Architecture & services', <_LessonNode>[
    _LessonNode('az900-l-regions', 'Régions & zones', 5, _NodeStatus.available),
    _LessonNode('az900-l-compute', 'Services de calcul', 7, _NodeStatus.locked),
  ]),
  _Unit('Gestion & gouvernance', <_LessonNode>[
    _LessonNode('az900-l-rbac', 'RBAC & Entra ID', 6, _NodeStatus.locked),
  ]),
];
