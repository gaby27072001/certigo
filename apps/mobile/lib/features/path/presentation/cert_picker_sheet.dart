import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';

/// Opens the Duolingo-style course picker: the learner browses the
/// certifications the app offers and taps one to switch the Path screen to it.
Future<void> showCertPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext _) => const CertPickerSheet(),
  );
}

/// French labels for the authoring levels. Certification titles themselves stay
/// in Microsoft's official English wording (e.g. "Azure Fundamentals").
const Map<String, String> _levelLabels = <String, String>{
  'fundamentals': 'Fondamentaux',
  'associate': 'Associé',
  'expert': 'Expert',
};

/// Bottom sheet listing every certification track, with the active one marked.
/// Reads the catalog lazily (only while open) and the active track from
/// [activeTrackProvider]; selecting a track updates that provider and closes.
class CertPickerSheet extends ConsumerWidget {
  const CertPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<List<TrackSummary>> catalog = ref.watch(catalogProvider);
    final String activeId = ref.watch(activeTrackProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: p.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Grip(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Mes certifications',
                            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Choisis le parcours à suivre',
                            style: text.labelMedium?.copyWith(color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close_rounded, color: p.textSecondary),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: catalog.when(
                  data: (List<TrackSummary> tracks) => _CertList(
                    tracks: tracks,
                    activeId: activeId,
                    onSelect: (String id) {
                      ref.read(activeTrackProvider.notifier).state = id;
                      Navigator.of(context).maybePop();
                    },
                  ),
                  loading: () => const _CertLoading(),
                  error: (Object _, StackTrace __) => _CertError(
                    onRetry: () => ref.invalidate(catalogProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertList extends StatelessWidget {
  const _CertList({
    required this.tracks,
    required this.activeId,
    required this.onSelect,
  });

  final List<TrackSummary> tracks;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      final PrismColorScheme p = context.prism;
      final TextTheme text = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        child: Text(
          'Aucune certification disponible pour le moment.',
          style: text.bodyMedium?.copyWith(color: p.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int i) {
        final TrackSummary track = tracks[i];
        return _CertCard(
          track: track,
          accent: context.prism.accentFor(i),
          selected: track.id == activeId,
          onTap: () => onSelect(track.id),
        );
      },
    );
  }
}

/// One Duolingo-style course card: a colored emblem with the exam code, the
/// official title, a level chip and lesson/chapter counts, plus a selected mark.
class _CertCard extends StatelessWidget {
  const _CertCard({
    required this.track,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final TrackSummary track;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final String level = _levelLabels[track.level] ?? track.level;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.10) : p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              _Emblem(code: track.code, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      track.title,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        track.summary,
                        style: text.bodySmall?.copyWith(color: p.textSecondary, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: <Widget>[
                        if (level.isNotEmpty) ...<Widget>[
                          _MetaChip(label: level, color: accent),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.menu_book_rounded, size: 14, color: p.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${track.lessonCount} leçons · ${track.unitCount} chapitres',
                            style: text.labelSmall?.copyWith(color: p.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? accent : p.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.code, required this.accent});

  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[accent, accent.withOpacity(0.74)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: PrismRadii.pillAll,
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      decoration: BoxDecoration(
        color: p.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _CertLoading extends StatelessWidget {
  const _CertLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        PrismSkeleton(height: 88),
        SizedBox(height: 12),
        PrismSkeleton(height: 88),
        SizedBox(height: 12),
        PrismSkeleton(height: 88),
      ],
    );
  }
}

class _CertError extends StatelessWidget {
  const _CertError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        const CalloutBlock(
          kind: CalloutKind.warning,
          title: 'Catalogue indisponible',
          text: 'Impossible de charger les certifications. Réessaie dans un instant.',
        ),
        const SizedBox(height: 18),
        PrismButton.secondary(
          label: 'Réessayer',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
