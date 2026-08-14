import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../home/application/home_controller.dart';
import '../../home/presentation/coach_section.dart';
import '../application/vendor_catalog.dart';

/// Library root — the top level of the Duolingo-style content shelf.
///
/// "Apprendre à ton rythme": a personalised "Pour toi" coaching shelf on top,
/// then the vendor catalogue — Microsoft and GitHub (real, with live
/// certification counts derived from [catalogProvider]) and Google, AWS and
/// OpenAI as showcase "bientôt" tiles. Tapping a real vendor drills into its
/// certifications.
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
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_awesome_rounded, size: 20, color: p.primary),
            const SizedBox(width: PrismSpacing.xs),
            Text('Pour toi', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
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
    final TextTheme t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Éditeurs', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: PrismSpacing.xxs),
        Text(
          'Choisis un éditeur pour explorer ses certifications',
          style: t.labelMedium?.copyWith(color: context.prism.textSecondary),
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
    final String subtitle = catalog.when(
      data: (List<TrackSummary> tracks) {
        final int count = tracksForVendor(tracks, vendor).length;
        return count <= 1 ? '$count certification' : '$count certifications';
      },
      loading: () => 'Chargement…',
      error: (_, __) => 'Catalogue indisponible',
    );

    return VendorTile(
      brand: vendor,
      subtitle: subtitle,
      onTap: () => context.push('${Routes.library}/vendor/${vendor.id}'),
    );
  }
}
