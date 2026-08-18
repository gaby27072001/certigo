import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../library/application/vendor_catalog.dart';

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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
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
                    tracks: pickerTracks(tracks),
                    activeId: activeId,
                    onSelect: (String id) {
                      ref.read(activeTrackProvider.notifier).state = id;
                      Navigator.of(context).maybePop();
                    },
                  ),
                  loading: () => const _CertLoading(),
                  error: (Object err, StackTrace __) {
                    final bool isEmptyCatalog = err is CatalogEmptyFailure ||
                        (err is ServerFailure && err.statusCode == 503);
                    return _CertError(
                      title: isEmptyCatalog ? 'Catalogue vide' : 'Catalogue indisponible',
                      message: err is Failure
                          ? err.message
                          : 'Impossible de charger les certifications. Réessaie dans un instant.',
                      calloutKind: isEmptyCatalog ? CalloutKind.info : CalloutKind.warning,
                      onRetry: () => ref.invalidate(catalogProvider),
                    );
                  },
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
  const _CertList({required this.tracks, required this.activeId, required this.onSelect});

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
        return CertificationCard(
          code: track.displayCode,
          title: track.title,
          summary: track.summary,
          levelLabel: levelLabelOf(track.normalizedLevel),
          lessonCount: track.hasLearningContent ? track.lessonCount : null,
          unitCount: track.hasLearningContent ? track.unitCount : null,
          statusLabel: track.isRetired
              ? 'Examen retiré'
              : track.hasLearningContent
                  ? ''
                  : 'Bientôt',
          accent: context.prism.accentFor(i),
          selected: track.id == activeId,
          onTap: track.hasLearningContent ? () => onSelect(track.id) : null,
        );
      },
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
      decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)),
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
  const _CertError({
    required this.onRetry,
    this.title = 'Catalogue indisponible',
    this.message = 'Impossible de charger les certifications. Réessaie dans un instant.',
    this.calloutKind = CalloutKind.warning,
  });

  final VoidCallback onRetry;
  final String title;
  final String message;
  final CalloutKind calloutKind;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        CalloutBlock(kind: calloutKind, title: title, text: message),
        const SizedBox(height: 18),
        PrismButton.secondary(label: 'Réessayer', icon: Icons.refresh_rounded, onPressed: onRetry),
      ],
    );
  }
}
