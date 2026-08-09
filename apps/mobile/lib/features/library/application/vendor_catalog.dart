import 'package:data/data.dart';
import 'package:prism_ui/prism_ui.dart';

/// Pure catalogue logic for the vendor → certification → chapter library.
///
/// The Certigo track model has no vendor or category field, so this module
/// *derives* both from the stable track id / exam code. Keeping the rules here
/// (rather than in widgets) makes them unit-testable and gives the whole
/// library one source of truth.

/// Derives the [VendorBrand] that owns a track.
///
/// The real content is Microsoft (~84 tracks) + GitHub (5 tracks); GitHub tracks
/// are the only ones whose id/code starts with "github"/"gh". Everything else is
/// Microsoft, the flagship vendor.
VendorBrand vendorOf(TrackSummary track) {
  final String id = track.id.toLowerCase();
  final String code = track.code.toLowerCase();
  if (id.startsWith('github') || id.startsWith('gh-') || code.startsWith('gh')) {
    return VendorBrand.github;
  }
  return VendorBrand.microsoft;
}

/// The vendors that have real, browsable catalogues today.
const List<VendorBrand> kRealVendors = <VendorBrand>[VendorBrand.microsoft, VendorBrand.github];

/// The showcase ("bientôt") vendors — displayed locked, with no tracks yet.
const List<VendorBrand> kShowcaseVendors = <VendorBrand>[
  VendorBrand.google,
  VendorBrand.aws,
  VendorBrand.openai,
];

/// Returns the tracks that belong to [vendor], preserving catalogue order.
List<TrackSummary> tracksForVendor(List<TrackSummary> catalog, VendorBrand vendor) =>
    catalog.where((TrackSummary t) => vendorOf(t) == vendor).toList(growable: false);

/// A thematic grouping of certifications within a vendor (Azure, Sécurité…).
///
/// Derived from the exam-code prefix so the certifications screen can present a
/// long list (Microsoft alone has ~84) as a handful of scannable sections rather
/// than a flat wall.
enum CertCategory {
  azure,
  security,
  dataAi,
  microsoft365,
  powerPlatform,
  dynamics365,
  mos,
  github,
  other,
}

/// Per-category French label and a stable display order.
extension CertCategoryInfo on CertCategory {
  /// French section title.
  String get label => switch (this) {
    CertCategory.azure => 'Azure',
    CertCategory.security => 'Sécurité',
    CertCategory.dataAi => 'Data & IA',
    CertCategory.microsoft365 => 'Microsoft 365',
    CertCategory.powerPlatform => 'Power Platform',
    CertCategory.dynamics365 => 'Dynamics 365',
    CertCategory.mos => 'Microsoft Office',
    CertCategory.github => 'GitHub',
    CertCategory.other => 'Autres',
  };

  /// Stable index into `PrismColors.domainAccents` for the section accent.
  int get accentIndex => switch (this) {
    CertCategory.azure => 0,
    CertCategory.security => 5,
    CertCategory.dataAi => 3,
    CertCategory.microsoft365 => 4,
    CertCategory.powerPlatform => 2,
    CertCategory.dynamics365 => 1,
    CertCategory.mos => 4,
    CertCategory.github => 1,
    CertCategory.other => 2,
  };

  /// Display order of the sections on the certifications screen.
  int get order => switch (this) {
    CertCategory.azure => 0,
    CertCategory.security => 1,
    CertCategory.dataAi => 2,
    CertCategory.microsoft365 => 3,
    CertCategory.powerPlatform => 4,
    CertCategory.dynamics365 => 5,
    CertCategory.mos => 6,
    CertCategory.github => 7,
    CertCategory.other => 8,
  };
}

/// Classifies a track into a [CertCategory] from its exam-code / id prefix.
CertCategory categoryOf(TrackSummary track) {
  final String code = track.code.toUpperCase();
  final String id = track.id.toLowerCase();

  if (id.startsWith('github') || id.startsWith('gh-') || code.startsWith('GH')) {
    return CertCategory.github;
  }
  // Two-letter exam family prefix (e.g. "AZ" from "AZ-900").
  final String prefix = code.split('-').first;
  return switch (prefix) {
    'AZ' => CertCategory.azure,
    'SC' => CertCategory.security,
    'AI' || 'DP' => CertCategory.dataAi,
    'MS' || 'MD' => CertCategory.microsoft365,
    'PL' => CertCategory.powerPlatform,
    'MB' => CertCategory.dynamics365,
    'MO' => CertCategory.mos,
    _ => CertCategory.other,
  };
}

/// French label for an authoring level (`fundamentals`/`associate`/`expert`).
String levelLabelOf(String level) => switch (level) {
  'fundamentals' => 'Fondamentaux',
  'associate' => 'Associé',
  'expert' => 'Expert',
  _ => level,
};

/// A category section: its [category] and the tracks it contains, in order.
class CertSection {
  const CertSection({required this.category, required this.tracks});

  final CertCategory category;
  final List<TrackSummary> tracks;
}

/// Groups [tracks] into ordered [CertSection]s, optionally filtered by a
/// free-text [query] matched against code, title and summary.
///
/// Empty categories are dropped; sections follow [CertCategoryInfo.order].
List<CertSection> groupIntoSections(List<TrackSummary> tracks, {String query = ''}) {
  final String q = query.trim().toLowerCase();
  final Iterable<TrackSummary> filtered = q.isEmpty
      ? tracks
      : tracks.where(
          (TrackSummary t) =>
              t.code.toLowerCase().contains(q) ||
              t.title.toLowerCase().contains(q) ||
              t.summary.toLowerCase().contains(q),
        );

  final Map<CertCategory, List<TrackSummary>> byCategory = <CertCategory, List<TrackSummary>>{};
  for (final TrackSummary track in filtered) {
    byCategory.putIfAbsent(categoryOf(track), () => <TrackSummary>[]).add(track);
  }

  final List<CertCategory> categories = byCategory.keys.toList()
    ..sort((CertCategory a, CertCategory b) => a.order.compareTo(b.order));

  return categories
      .map((CertCategory c) => CertSection(category: c, tracks: byCategory[c]!))
      .toList(growable: false);
}
