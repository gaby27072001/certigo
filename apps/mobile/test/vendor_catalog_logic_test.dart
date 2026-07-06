import 'package:certigo/features/library/application/vendor_catalog.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Pure unit tests for the vendor/category derivation that powers the library
/// catalogue. No widgets, no providers — just the classification rules.
void main() {
  TrackSummary track(String id, String code, {String level = 'fundamentals'}) => TrackSummary(
        id: id,
        code: code,
        title: '$code title',
        level: level,
        summary: 'summary of $code',
        unitCount: 5,
        lessonCount: 20,
      );

  group('vendorOf', () {
    test('maps GitHub tracks by id/code prefix and everything else to Microsoft', () {
      expect(vendorOf(track('github-foundations', 'GH-900')), VendorBrand.github);
      expect(vendorOf(track('gh-actions', 'GHA-100')), VendorBrand.github);
      expect(vendorOf(track('az-900', 'AZ-900')), VendorBrand.microsoft);
      expect(vendorOf(track('sc-900', 'SC-900')), VendorBrand.microsoft);
    });
  });

  group('categoryOf', () {
    test('classifies tracks by exam-code family', () {
      expect(categoryOf(track('az-900', 'AZ-900')), CertCategory.azure);
      expect(categoryOf(track('sc-900', 'SC-900')), CertCategory.security);
      expect(categoryOf(track('ai-900', 'AI-900')), CertCategory.dataAi);
      expect(categoryOf(track('dp-900', 'DP-900')), CertCategory.dataAi);
      expect(categoryOf(track('ms-900', 'MS-900')), CertCategory.microsoft365);
      expect(categoryOf(track('pl-900', 'PL-900')), CertCategory.powerPlatform);
      expect(categoryOf(track('mb-910', 'MB-910')), CertCategory.dynamics365);
      expect(categoryOf(track('mo-100', 'MO-100')), CertCategory.mos);
      expect(categoryOf(track('github-foundations', 'GH-900')), CertCategory.github);
      expect(categoryOf(track('xy-1', 'XY-1')), CertCategory.other);
    });
  });

  group('levelLabelOf', () {
    test('localises the three known authoring levels', () {
      expect(levelLabelOf('fundamentals'), 'Fondamentaux');
      expect(levelLabelOf('associate'), 'Associé');
      expect(levelLabelOf('expert'), 'Expert');
      expect(levelLabelOf('unknown'), 'unknown');
    });
  });

  group('tracksForVendor', () {
    test('keeps only the tracks owned by the vendor, in order', () {
      final List<TrackSummary> catalog = <TrackSummary>[
        track('az-900', 'AZ-900'),
        track('github-foundations', 'GH-900'),
        track('sc-900', 'SC-900'),
      ];
      final List<TrackSummary> ms = tracksForVendor(catalog, VendorBrand.microsoft);
      expect(ms.map((TrackSummary t) => t.id), <String>['az-900', 'sc-900']);
      expect(tracksForVendor(catalog, VendorBrand.github).single.id, 'github-foundations');
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
      expect(
        sections.map((CertSection s) => s.category),
        <CertCategory>[CertCategory.azure, CertCategory.security, CertCategory.dataAi],
      );
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
