import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../home/application/home_controller.dart';
import '../../home/presentation/coach_section.dart';
import '../application/vendor_catalog.dart';

/// Library root — the top level of the Duolingo-style content shelf.
///
/// "Apprendre à ton rythme": a personalised "Pour toi" coaching shelf on top,
/// then the provider catalogue. Certification counts come from the API-backed
/// [catalogProvider], including planned AWS and Google Cloud learning tracks.
class VendorCatalogScreen extends ConsumerWidget {
  const VendorCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeData> home = ref.watch(homeDataProvider);
    final AsyncValue<List<TrackSummary>> catalog = ref.watch(catalogProvider);
    final TextTheme t = Theme.of(context).textTheme;

    return AuroraBackground(
      animate: true,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
          children: <Widget>[
            _ResourceBar(home: home),
            const SizedBox(height: PrismSpacing.md),
            Text('Bibliothèque', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: PrismSpacing.lg),
            _PourToiSection(home: home),
            const SizedBox(height: PrismSpacing.xl),
            _VendorSection(catalog: catalog),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Resource bar ────────────────────────────────

class _ResourceBar extends StatelessWidget {
  const _ResourceBar({required this.home});

  final AsyncValue<HomeData> home;

  @override
  Widget build(BuildContext context) {
    return home.maybeWhen(
      loading: () => const Row(
        children: <Widget>[
          PrismSkeleton(width: 72, height: 32),
          SizedBox(width: PrismSpacing.xs),
          PrismSkeleton(width: 72, height: 32),
          Spacer(),
          PrismSkeleton(width: 72, height: 32),
        ],
      ),
      data: (HomeData data) => Row(
        children: <Widget>[
          StreakBadge(days: data.profile.streakDays, active: data.profile.dailyProgress >= 1),
          const SizedBox(width: PrismSpacing.xs),
          GemCounter(gems: data.profile.gems),
          const Spacer(),
          XpChip(xp: data.profile.xp),
        ],
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────── Pour toi ────────────────────────────────────

class _PourToiSection extends StatelessWidget {
  const _PourToiSection({required this.home});

  final AsyncValue<HomeData> home;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(
          title: 'Pour toi',
          subtitle: 'La meilleure prochaine action selon ta progression',
          icon: Icons.auto_awesome_rounded,
          compact: true,
        ),
        const SizedBox(height: PrismSpacing.md),
        home.when(
          data: (HomeData data) => CoachSection(trackId: data.path.trackId),
          loading: _buildSkeleton,
          error: (_, __) => _buildEmpty(context),
        ),
      ],
    );
  }

  static Widget _buildSkeleton() {
    return const PrismCard(
      elevation: 0,
      padding: EdgeInsets.all(PrismSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PrismSkeleton(height: 14, width: 180),
          SizedBox(height: PrismSpacing.xs),
          PrismSkeleton(height: 12),
          SizedBox(height: PrismSpacing.xxs),
          PrismSkeleton(height: 12, width: 220),
        ],
      ),
    );
  }

  static Widget _buildEmpty(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        const MascotAvatar(mascot: AuroraMascot.nimbus, size: 72),
        const SizedBox(height: PrismSpacing.sm),
        Text(
          'Commence des leçons pour recevoir\ndes recommandations personnalisées !',
          textAlign: TextAlign.center,
          style: t.bodyMedium,
        ),
      ],
    );
  }
}

// ─────────────────────────────── Éditeurs ────────────────────────────────────

class _VendorSection extends StatelessWidget {
  const _VendorSection({required this.catalog});

  final AsyncValue<List<TrackSummary>> catalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(
          title: 'Éditeurs',
          subtitle: 'Choisis un éditeur pour explorer ses certifications',
          icon: Icons.apartment_rounded,
          compact: true,
        ),
        const SizedBox(height: PrismSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: PrismSpacing.sm,
          crossAxisSpacing: PrismSpacing.sm,
          childAspectRatio: 1.05,
          children: <Widget>[
            for (final VendorBrand vendor in kRealVendors)
              _RealVendorTile(vendor: vendor, catalog: catalog),
            for (final VendorBrand vendor in kShowcaseVendors)
              VendorTile(brand: vendor, subtitle: 'Bientôt', locked: true),
          ],
        ),
      ],
    );
  }
}

/// A tile for a real vendor: the certification count reflects [catalogProvider].
class _RealVendorTile extends StatelessWidget {
  const _RealVendorTile({required this.vendor, required this.catalog});

  final VendorBrand vendor;
  final AsyncValue<List<TrackSummary>> catalog;

  @override
  Widget build(BuildContext context) {
    return catalog.when(
      data: (List<TrackSummary> tracks) {
        final int count = tracksForVendor(tracks, vendor).length;
        return VendorTile(
          brand: vendor,
          subtitle: count <= 1 ? '$count certification' : '$count certifications',
          onTap: count == 0 ? null : () => context.push(vendorLocation(vendor)),
        );
      },
      loading: () => VendorTile(brand: vendor, subtitle: 'Chargement…'),
      error: (_, __) => VendorTile(brand: vendor, subtitle: 'Catalogue indisponible'),
    );
  }
}
