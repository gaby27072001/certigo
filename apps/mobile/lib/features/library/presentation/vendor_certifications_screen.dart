import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
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
                    for (final CertSection section in sections)
                      _CategorySection(section: section, vendor: widget.vendor),
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
  const _CategorySection({required this.section, required this.vendor});

  final CertSection section;
  final VendorBrand vendor;

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
            child: CertificationCard(
              code: track.code,
              title: track.title,
              summary: track.summary,
              levelLabel: levelLabelOf(track.level),
              lessonCount: track.lessonCount,
              unitCount: track.unitCount,
              accent: accent,
              onTap: () => context.push(
                '${Routes.library}/vendor/${vendor.id}/cert/${track.id}',
              ),
            ),
          ),
      ],
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
        CalloutBlock(
          kind: CalloutKind.warning,
          title: 'Catalogue indisponible',
          text: message,
        ),
        const SizedBox(height: PrismSpacing.md),
        PrismButton.secondary(
          label: 'Réessayer',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
