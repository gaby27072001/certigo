import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/router.dart';
import '../../home/application/home_controller.dart';
import '../../home/presentation/coach_section.dart';

/// Library — "Apprendre à ton rythme". Combines AI-driven personalised tips
/// ("Pour toi") with a full Azure-domain catalogue ("Explorer") so learners can
/// both follow the coach and browse freely.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeData> async = ref.watch(homeDataProvider);
    final TextTheme t = Theme.of(context).textTheme;

    return AuroraBackground(
      animate: true,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: <Widget>[
            // Resource bar mirrors Home so moving between tabs feels seamless.
            async.maybeWhen(
              data: (HomeData data) => Row(
                children: <Widget>[
                  StreakBadge(
                    days: data.profile.streakDays,
                    active: data.profile.dailyProgress >= 1,
                  ),
                  const SizedBox(width: 8),
                  GemCounter(gems: data.profile.gems),
                  const Spacer(),
                  XpChip(xp: data.profile.xp),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 18),

            Text(
              'Bibliothèque',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 22),

            _PourToiSection(async: async),
            const SizedBox(height: 32),

            const _ExplorerSection(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Pour toi ────────────────────────────────────

class _PourToiSection extends StatelessWidget {
  const _PourToiSection({required this.async});

  final AsyncValue<HomeData> async;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_awesome_rounded, size: 20, color: p.primary),
            const SizedBox(width: 8),
            Text(
              'Pour toi',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        async.when(
          data: (HomeData data) => _PourToiContent(data: data),
          loading: () => _buildSkeleton(context),
          error: (_, __) => _buildEmpty(context),
        ),
      ],
    );
  }

  static Widget _buildSkeleton(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return PrismCard(
      elevation: 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(height: 14, width: 180, color: p.border),
          const SizedBox(height: 8),
          Container(height: 12, width: double.infinity, color: p.border),
          const SizedBox(height: 4),
          Container(height: 12, width: 220, color: p.border),
        ],
      ),
    );
  }

  static Widget _buildEmpty(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        const MascotAvatar(mascot: AuroraMascot.nimbus, size: 72),
        const SizedBox(height: 12),
        Text(
          'Commence des leçons pour recevoir\ndes recommandations personnalisées !',
          textAlign: TextAlign.center,
          style: t.bodyMedium,
        ),
      ],
    );
  }
}

class _PourToiContent extends StatelessWidget {
  const _PourToiContent({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    // Show a "Le sais-tu ?" tip card when the weakest domain score suggests
    // the learner is struggling (score < 60 is a reasonable proxy until
    // consecutiveErrors is available from the API).
    final bool showTip =
        data.weakestDomain != null && (data.weakestDomain!.score) < 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showTip) ...<Widget>[
          _TipCard(p: p, t: t),
          const SizedBox(height: 16),
        ],
        CoachSection(trackId: data.path.trackId),
        if (!showTip && data.weakestDomain == null) _PourToiSection._buildEmpty(context),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.p, required this.t});

  final PrismColorScheme p;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: p.warning,
      elevation: 0,
      padding: const EdgeInsets.all(16),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('💡', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Le sais-tu ?',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Un Azure Blob est un espace de stockage d\'objets non '
                    'structurés dans le cloud. Parfait pour images, vidéos, '
                    'fichiers de log.',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: p.primary,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {},
                    child: const Text('En savoir plus →'),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }
}

// ─────────────────────────────── Explorer ────────────────────────────────────

class _ExplorerSection extends StatelessWidget {
  const _ExplorerSection();

  static const List<({String emoji, String label, Color color})> _domains = <
      ({
        String emoji,
        String label,
        Color color
      })>[
    (emoji: '☁️', label: 'Compute', color: Colors.blue),
    (emoji: '🗄️', label: 'Storage', color: Colors.orange),
    (emoji: '🤖', label: 'AI', color: Colors.purple),
    (emoji: '🔒', label: 'Security', color: Colors.red),
    (emoji: '🌐', label: 'Networking', color: Colors.teal),
    (emoji: '⚙️', label: 'DevOps', color: Colors.indigo),
    (emoji: '📊', label: 'Monitoring', color: Colors.green),
    (emoji: '🚀', label: 'Serverless', color: Colors.deepOrange),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Explorer',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: _domains
              .map((({String emoji, String label, Color color}) d) =>
                  _DomainCard(emoji: d.emoji, label: d.label, color: d.color))
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.emoji, required this.label, required this.color});

  final String emoji;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.push('${Routes.library}/domain/${label.toLowerCase()}'),
      child: PrismCard(
        variant: PrismCardVariant.tonal,
        accent: color,
        elevation: 0,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '— leçons',
              style: t.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
