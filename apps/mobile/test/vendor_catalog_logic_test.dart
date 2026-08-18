import 'package:certigo/features/library/application/vendor_catalog.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Pure unit tests for the vendor/category derivation that powers the library
/// catalogue. No widgets, no providers — just the classification rules.
void main() {
  TrackSummary track(
    String id,
    String code, {
    String level = 'fundamentals',
    CertificationProvider provider = CertificationProvider.microsoft,
    String family = 'other',
    CertificationLifecycleStatus status = CertificationLifecycleStatus.active,
    CertificationContentStatus contentStatus = CertificationContentStatus.available,
  }) =>
      TrackSummary(
        id: id,
        code: code,
        title: '$code title',
        level: level,
        summary: 'summary of $code',
        unitCount: 5,
        lessonCount: 20,
        provider: provider,
        family: family,
        status: status,
        contentStatus: contentStatus,
      );

  group('vendorOf', () {
    test('maps explicit providers without relying on exam-code prefixes', () {
      expect(
        vendorOf(track('github-foundations', 'GH-900', provider: CertificationProvider.github)),
        VendorBrand.github,
      );
      expect(vendorOf(track('az-900', 'AZ-900')), VendorBrand.microsoft);
      expect(
        vendorOf(track('aws-saa-c03', 'SAA-C03', provider: CertificationProvider.aws)),
        VendorBrand.aws,
      );
      expect(
        vendorOf(track('gcp-cloud-digital-leader', '', provider: CertificationProvider.gcp)),
        VendorBrand.google,
      );
    });
  });

  group('categoryOf', () {
    test('classifies tracks by exam-code family', () {
      expect(categoryOf(track('az-900', 'AZ-900')), CertCategory.azure);
      expect(categoryOf(track('sc-900', 'SC-900')), CertCategory.security);
      expect(categoryOf(track('ai-900', 'AI-900')), CertCategory.dataAi);
      expect(categoryOf(track('ai-901', 'AI-901')), CertCategory.dataAi);
      expect(categoryOf(track('dp-900', 'DP-900')), CertCategory.dataAi);
      expect(categoryOf(track('ms-900', 'MS-900')), CertCategory.microsoft365);
      expect(categoryOf(track('pl-900', 'PL-900')), CertCategory.powerPlatform);
      expect(categoryOf(track('mb-910', 'MB-910')), CertCategory.dynamics365);
      expect(categoryOf(track('mo-100', 'MO-100')), CertCategory.mos);
      expect(categoryOf(track('github-foundations', 'GH-900')), CertCategory.github);
      expect(categoryOf(track('xy-1', 'XY-1')), CertCategory.other);
      expect(
        categoryOf(track('aws-saa-c03', 'SAA-C03', family: 'architecture')),
        CertCategory.architecture,
      );
      expect(
        categoryOf(track('gcp-security', '', family: 'security-operations')),
        CertCategory.security,
      );
    });
  });

  group('levelLabelOf', () {
    test('localises the four provider-neutral levels', () {
      expect(levelLabelOf(CertificationLevel.foundational), 'Fondamentaux');
      expect(levelLabelOf(CertificationLevel.associate), 'Associé');
      expect(levelLabelOf(CertificationLevel.professional), 'Professionnel');
      expect(levelLabelOf(CertificationLevel.specialty), 'Spécialité');
    });
  });

  group('tracksForVendor', () {
    test('keeps only the tracks owned by the vendor, in order', () {
      final List<TrackSummary> catalog = <TrackSummary>[
        track('az-900', 'AZ-900'),
        track('github-foundations', 'GH-900', provider: CertificationProvider.github),
        track('sc-900', 'SC-900'),
        track(
          'aws-ans-c01',
          'ANS-C01',
          provider: CertificationProvider.aws,
          status: CertificationLifecycleStatus.retired,
          contentStatus: CertificationContentStatus.planned,
        ),
      ];
      final List<TrackSummary> ms = tracksForVendor(catalog, VendorBrand.microsoft);
      expect(ms.map((TrackSummary t) => t.id), <String>['az-900', 'sc-900']);
      expect(tracksForVendor(catalog, VendorBrand.github).single.id, 'github-foundations');
      expect(tracksForVendor(catalog, VendorBrand.aws), isEmpty);
    });
  });

  group('selectableTracks', () {
    test('keeps authored history while excluding planned entries', () {
      final List<TrackSummary> catalog = <TrackSummary>[
        track('az-900', 'AZ-900'),
        track(
          'aws-aif-c01',
          'AIF-C01',
          provider: CertificationProvider.aws,
          contentStatus: CertificationContentStatus.planned,
        ),
        track('retired', 'OLD-001', status: CertificationLifecycleStatus.retired),
      ];

      expect(selectableTracks(catalog).map((TrackSummary track) => track.id), <String>[
        'az-900',
        'retired',
      ]);
    });
  });

  group('deep links', () {
    test('encode the provider carried by catalog metadata', () {
      final TrackSummary aws = track('aws-saa-c03', 'SAA-C03', provider: CertificationProvider.aws);
      final TrackSummary gcp = track(
        'gcp-cloud-digital-leader',
        '',
        provider: CertificationProvider.gcp,
      );

      expect(certificationLocation(aws), '/library/vendor/aws/cert/aws-saa-c03');
      expect(certificationLocation(gcp), '/library/vendor/gcp/cert/gcp-cloud-digital-leader');
      expect(VendorBrandInfo.fromId('gcp'), VendorBrand.google);
      expect(VendorBrandInfo.fromId('google'), VendorBrand.google);
    });
  });

  group('groupIntoSections', () {
    final List<TrackSummary> tracks = <TrackSummary>[
      track('sc-900', 'SC-900'),
      track('az-900', 'AZ-900'),
      track('az-104', 'AZ-104', level: 'associate'),
      track('ai-900', 'AI-900'),
    ];

    test('groups into ordered, non-empty sections', () {
      final List<CertSection> sections = groupIntoSections(tracks);
      expect(sections.map((CertSection s) => s.category), <CertCategory>[
        CertCategory.azure,
        CertCategory.security,
        CertCategory.dataAi,
      ]);
      expect(sections.first.tracks.length, 2); // AZ-900 + AZ-104
    });

    test('filters by free-text query across code and title', () {
      final List<CertSection> sections = groupIntoSections(tracks, query: 'az');
      expect(sections.length, 1);
      expect(sections.single.category, CertCategory.azure);
      expect(sections.single.tracks.length, 2);
    });

    test('returns no sections when nothing matches', () {
      expect(groupIntoSections(tracks, query: 'zzz'), isEmpty);
    });
  });
}
