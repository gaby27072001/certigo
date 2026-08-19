import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../application/vendor_catalog.dart';

/// Second level of the catalogue: every certification a [vendor] offers.
///
/// Reads [catalogProvider], keeps only the tracks that belong to the vendor and
/// presents them as scannable, category-grouped sections (Azure, Sécurité,
/// Data & IA, Microsoft 365…) with a search box — Microsoft alone ships ~84
/// tracks, so a flat list is out. Tapping a card drills into its chapters.
class VendorCertificationsScreen extends ConsumerStatefulWidget {
  const VendorCertificationsScreen({super.key, required this.vendor});

  final VendorBrand vendor;

  @override
  ConsumerState<VendorCertificationsScreen> createState() => _VendorCertificationsScreenState();
}

class _VendorCertificationsScreenState extends ConsumerState<VendorCertificationsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final AsyncValue<List<TrackSummary>> catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            VendorLogo(brand: widget.vendor, size: 26),
            const SizedBox(width: PrismSpacing.xs),
            Text(
              'Certifications ${widget.vendor.label}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: catalog.when(
          data: (List<TrackSummary> tracks) => _buildBody(context, p, tracks),
          loading: () => const _LoadingList(),
          error: (Object err, StackTrace __) => _ErrorView(
            message: err is Failure
                ? err.message
                : 'Impossible de charger les certifications. Réessaie dans un instant.',
            onRetry: () => ref.invalidate(catalogProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PrismColorScheme p, List<TrackSummary> allTracks) {
    final List<TrackSummary> vendorTracks = tracksForVendor(allTracks, widget.vendor);
    final List<CertSection> sections = groupIntoSections(vendorTracks, query: _query);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.gutter,
            PrismSpacing.sm,
            PrismSpacing.gutter,
            PrismSpacing.xs,
          ),
          child: _SearchField(
            controller: _search,
            onChanged: (String value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: sections.isEmpty
              ? _EmptyResults(query: _query)
              : ListView(
                  padding: PrismSpacing.scrollBody(top: PrismSpacing.xs),
                  children: <Widget>[
                    for (final CertSection section in sections) _CategorySection(section: section),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher une certification',
        prefixIcon: Icon(Icons.search_rounded, color: p.textSecondary),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.md,
          vertical: PrismSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: PrismRadii.cardMd,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardMd,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardMd,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// A titled category section with its stack of certification cards.
class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.section});

  final CertSection section;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color accent = p.accentFor(section.category.accentIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: PrismSpacing.md, bottom: PrismSpacing.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: PrismSpacing.xxs,
                height: 18,
                decoration: BoxDecoration(color: accent, borderRadius: PrismRadii.pillAll),
              ),
              const SizedBox(width: PrismSpacing.xs),
              Text(
                section.category.label,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: PrismSpacing.xs),
              Text(
                '${section.tracks.length}',
                style: t.labelMedium?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        for (final TrackSummary track in section.tracks)
          Padding(
            padding: const EdgeInsets.only(bottom: PrismSpacing.sm),
            child: Column(
              children: <Widget>[
                CertificationCard(
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
                          : 'Parcours à venir',
                  accent: accent,
                  onTap: track.hasLearningContent
                      ? () => context.push(certificationLocation(track))
                      : null,
                ),
                if (track.hasOfficialMetadata) _OfficialMetadataPanel(track: track, accent: accent),
              ],
            ),
          ),
      ],
    );
  }
}

class _OfficialMetadataPanel extends StatelessWidget {
  const _OfficialMetadataPanel({required this.track, required this.accent});

  final TrackSummary track;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final String headline = track.isRetired
        ? 'Examen retiré · parcours archivé'
        : track.blueprintLabel.isEmpty
            ? 'Référentiel officiel'
            : 'Référentiel officiel · ${track.blueprintLabel}';
    final String providerLabel = track.provider.displayName;
    final String studyGuideLabel = track.provider == CertificationProvider.microsoft
        ? 'Guide officiel Microsoft Learn'
        : 'Guide officiel $providerLabel';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: PrismSpacing.sm),
        childrenPadding: const EdgeInsets.fromLTRB(
          PrismSpacing.sm,
          0,
          PrismSpacing.sm,
          PrismSpacing.sm,
        ),
        leading: Icon(
          track.isRetired ? Icons.event_busy_rounded : Icons.verified_rounded,
          color: track.isRetired ? p.error : accent,
          size: 20,
        ),
        title: Text(headline, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        subtitle: Text('Détails et liens $providerLabel'),
        children: <Widget>[
          if (track.lifecycleNote.isNotEmpty)
            _MetadataText(text: track.lifecycleNote, color: track.isRetired ? p.error : p.info),
          if (track.replacementCode.isNotEmpty)
            _MetadataText(text: 'Certification active de remplacement : ${track.replacementCode}'),
          if (track.migrationNote.isNotEmpty)
            _MetadataText(text: track.migrationNote, color: p.textSecondary),
          if (track.retiresOn?.isNotEmpty ?? false)
            _MetadataText(text: 'Retrait annoncé : ${track.retiresOn}', color: p.warning),
          if (track.retiredOn?.isNotEmpty ?? false)
            _MetadataText(text: 'Retirée le ${track.retiredOn}', color: p.error),
          for (final CertificationDomain domain in track.domains)
            Padding(
              padding: const EdgeInsets.only(bottom: PrismSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: Text(domain.name, style: t.bodySmall)),
                  const SizedBox(width: PrismSpacing.sm),
                  Text(
                    domain.weightLabel,
                    style: t.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          for (final CertificationObjective objective
              in track.blueprint?.objectives ?? const <CertificationObjective>[])
            Padding(
              padding: const EdgeInsets.only(bottom: PrismSpacing.xxs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(objective.title, style: t.bodySmall)),
                  const SizedBox(width: PrismSpacing.sm),
                  Text(
                    objective.weightLabel,
                    style: t.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          if (track.prerequisites.isNotEmpty) ...<Widget>[
            const SizedBox(height: PrismSpacing.xs),
            _MetadataText(text: 'Prérequis : ${track.prerequisites}'),
          ],
          if (track.durationMinutes != null)
            _MetadataText(text: 'Durée publiée : ${track.durationMinutes} min'),
          if (track.languages.isNotEmpty)
            _MetadataText(text: 'Langues publiées : ${track.languages.join(', ')}'),
          if (track.officialStudyGuideUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: PrismSpacing.xs),
            _MetadataLink(label: studyGuideLabel, url: track.officialStudyGuideUrl),
          ],
          if (track.officialExamUrl.isNotEmpty)
            _MetadataLink(label: 'Page officielle de la certification', url: track.officialExamUrl),
          if (track.examDetailsNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: PrismSpacing.xs),
            _MetadataText(text: track.examDetailsNote, color: p.textSecondary),
          ],
        ],
      ),
    );
  }
}

class _MetadataText extends StatelessWidget {
  const _MetadataText({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
    );
  }
}

class _MetadataLink extends StatelessWidget {
  const _MetadataLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final Color primary = context.prism.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: t.labelMedium?.copyWith(color: primary, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Copier le lien $label',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                color: primary,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Lien officiel copié')));
                },
              ),
            ],
          ),
          SelectableText(url, style: t.bodySmall?.copyWith(color: primary)),
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
        PrismSkeleton(height: 44),
        SizedBox(height: PrismSpacing.md),
        PrismSkeleton(height: 92),
        SizedBox(height: PrismSpacing.sm),
        PrismSkeleton(height: 92),
        SizedBox(height: PrismSpacing.sm),
        PrismSkeleton(height: 92),
      ],
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

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
              query.isEmpty
                  ? 'Aucune certification disponible pour le moment.'
                  : 'Aucun résultat pour « $query ».',
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
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(PrismSpacing.gutter),
      children: <Widget>[
        const SizedBox(height: PrismSpacing.md),
        CalloutBlock(kind: CalloutKind.warning, title: 'Catalogue indisponible', text: message),
        const SizedBox(height: PrismSpacing.md),
        PrismButton.secondary(label: 'Réessayer', icon: Icons.refresh_rounded, onPressed: onRetry),
      ],
    );
  }
}
