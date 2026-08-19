import 'package:data/data.dart';
import 'package:prism_ui/prism_ui.dart';

/// Pure catalogue logic for the provider → certification → chapter library.
VendorBrand vendorOf(TrackSummary track) => switch (track.provider) {
      CertificationProvider.microsoft => VendorBrand.microsoft,
      CertificationProvider.aws => VendorBrand.aws,
      CertificationProvider.gcp => VendorBrand.google,
      CertificationProvider.github => VendorBrand.github,
    };

/// The vendors that have real, browsable catalogues today.
const List<VendorBrand> kRealVendors = <VendorBrand>[
  VendorBrand.microsoft,
  VendorBrand.aws,
  VendorBrand.google,
  VendorBrand.github,
];

/// The showcase ("bientôt") vendors — displayed locked, with no tracks yet.
const List<VendorBrand> kShowcaseVendors = <VendorBrand>[VendorBrand.openai];

/// Returns discoverable certifications for [vendor], preserving catalogue order.
///
/// Retired entries remain visible only when authored learning content preserves
/// historical progress, as with AI-900.
List<TrackSummary> tracksForVendor(List<TrackSummary> catalog, VendorBrand vendor) => catalog
    .where(
      (TrackSummary track) =>
          vendorOf(track) == vendor && (track.isDiscoverable || track.hasLearningContent),
    )
    .toList(growable: false);

/// Only authored tracks may become the learner's active path.
List<TrackSummary> selectableTracks(List<TrackSummary> catalog) =>
    catalog.where((TrackSummary track) => track.hasLearningContent).toList(growable: false);

/// The path picker keeps planned Microsoft replacements visible as disabled
/// choices, without flooding it with every future external-provider track.
List<TrackSummary> pickerTracks(List<TrackSummary> catalog) => catalog
    .where(
      (TrackSummary track) =>
          track.hasLearningContent ||
          (track.provider == CertificationProvider.microsoft &&
              track.contentStatus == CertificationContentStatus.planned),
    )
    .toList(growable: false);

String vendorLocation(VendorBrand vendor) => '/library/vendor/${vendor.id}';

String certificationLocation(TrackSummary track) =>
    '${vendorLocation(vendorOf(track))}/cert/${Uri.encodeComponent(track.id)}';

/// A thematic grouping of certifications within a vendor (Azure, Sécurité…).
///
/// Derived from the exam-code prefix so the certifications screen can present a
/// long list (Microsoft alone has ~84) as a handful of scannable sections rather
/// than a flat wall.
enum CertCategory {
  foundations,
  azure,
  architecture,
  development,
  operations,
  data,
  ai,
  security,
  dataAi,
  devops,
  networking,
  database,
  collaboration,
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
        CertCategory.foundations => 'Fondamentaux cloud',
        CertCategory.azure => 'Azure',
        CertCategory.architecture => 'Architecture',
        CertCategory.development => 'Développement',
        CertCategory.operations => 'Opérations cloud',
        CertCategory.data => 'Données',
        CertCategory.ai => 'IA & machine learning',
        CertCategory.security => 'Sécurité',
        CertCategory.dataAi => 'Data & IA',
        CertCategory.devops => 'DevOps',
        CertCategory.networking => 'Réseau',
        CertCategory.database => 'Bases de données',
        CertCategory.collaboration => 'Collaboration',
        CertCategory.microsoft365 => 'Microsoft 365',
        CertCategory.powerPlatform => 'Power Platform',
        CertCategory.dynamics365 => 'Dynamics 365',
        CertCategory.mos => 'Microsoft Office',
        CertCategory.github => 'GitHub',
        CertCategory.other => 'Autres',
      };

  /// Stable index into `PrismColors.domainAccents` for the section accent.
  int get accentIndex => switch (this) {
        CertCategory.foundations => 0,
        CertCategory.azure => 0,
        CertCategory.architecture => 1,
        CertCategory.development => 2,
        CertCategory.operations => 4,
        CertCategory.data => 4,
        CertCategory.ai => 3,
        CertCategory.security => 5,
        CertCategory.dataAi => 3,
        CertCategory.devops => 2,
        CertCategory.networking => 1,
        CertCategory.database => 4,
        CertCategory.collaboration => 0,
        CertCategory.microsoft365 => 4,
        CertCategory.powerPlatform => 2,
        CertCategory.dynamics365 => 1,
        CertCategory.mos => 4,
        CertCategory.github => 1,
        CertCategory.other => 2,
      };

  /// Display order of the sections on the certifications screen.
  int get order => switch (this) {
        CertCategory.foundations => 0,
        CertCategory.azure => 1,
        CertCategory.architecture => 2,
        CertCategory.development => 3,
        CertCategory.operations => 4,
        CertCategory.data => 5,
        CertCategory.ai => 6,
        CertCategory.security => 7,
        CertCategory.dataAi => 8,
        CertCategory.devops => 9,
        CertCategory.networking => 10,
        CertCategory.database => 11,
        CertCategory.collaboration => 12,
        CertCategory.microsoft365 => 13,
        CertCategory.powerPlatform => 14,
        CertCategory.dynamics365 => 15,
        CertCategory.mos => 16,
        CertCategory.github => 17,
        CertCategory.other => 18,
      };
}

/// Classifies explicit multi-cloud families, then falls back to catalog-v1 codes.
CertCategory categoryOf(TrackSummary track) {
  final CertCategory? explicit = switch (track.family) {
    'cloud-foundations' => CertCategory.foundations,
    'architecture' => CertCategory.architecture,
    'development' => CertCategory.development,
    'operations' => CertCategory.operations,
    'data' => CertCategory.data,
    'ai' || 'machine-learning' || 'generative-ai' => CertCategory.ai,
    'devops' => CertCategory.devops,
    'security' || 'security-operations' => CertCategory.security,
    'networking' => CertCategory.networking,
    'database' => CertCategory.database,
    'collaboration' || 'workspace' => CertCategory.collaboration,
    _ => null,
  };
  if (explicit != null) return explicit;

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

/// French label for the provider-neutral certification tiers.
String levelLabelOf(CertificationLevel level) => switch (level) {
      CertificationLevel.foundational => 'Fondamentaux',
      CertificationLevel.associate => 'Associé',
      CertificationLevel.professional => 'Professionnel',
      CertificationLevel.specialty => 'Spécialité',
      CertificationLevel.unspecified => '',
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
              t.summary.toLowerCase().contains(q) ||
              t.prerequisites.toLowerCase().contains(q) ||
              t.replacementCode.toLowerCase().contains(q) ||
              t.migrationNote.toLowerCase().contains(q) ||
              t.domains.any((CertificationDomain domain) => domain.name.toLowerCase().contains(q)),
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
