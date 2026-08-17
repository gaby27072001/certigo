import 'package:data/data.dart';
import 'package:test/test.dart';

TrackSummary _track({
  String id = 'az-900',
  String code = 'AZ-900',
  String title = 'Microsoft Azure Fundamentals',
}) =>
    TrackSummary(
      id: id,
      code: code,
      title: title,
      level: 'fundamentals',
      summary: 'Summary',
      unitCount: 4,
      lessonCount: 20,
      domains: const <CertificationDomain>[
        CertificationDomain(
          id: 'cloud-concepts',
          name: 'Describe cloud concepts',
          minWeightPct: 25,
          maxWeightPct: 30,
        ),
      ],
      prerequisites: 'Aucun prérequis formel.',
      studyGuideUrl:
          'https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-900',
      examUrl: 'https://learn.microsoft.com/en-us/credentials/certifications/exams/az-900/',
      blueprintDate: '2026-07-20',
      lifecycle: 'active',
      examDetailsNote: 'Les détails peuvent changer.',
    );

void main() {
  group('JsonCatalogCacheStore', () {
    test('returns null when cache is absent', () async {
      String? persisted;
      final JsonCatalogCacheStore store = JsonCatalogCacheStore(
        read: () async => persisted,
        write: (String json) async => persisted = json,
      );

      final List<TrackSummary>? loaded = await store.read();
      expect(loaded, isNull);
    });

    test('writes and reads catalog round-trip', () async {
      String? persisted;
      final JsonCatalogCacheStore store = JsonCatalogCacheStore(
        read: () async => persisted,
        write: (String json) async => persisted = json,
      );

      await store.write(<TrackSummary>[
        _track(),
        _track(id: 'sc-900', code: 'SC-900', title: 'Microsoft Security Fundamentals'),
      ]);

      final List<TrackSummary>? loaded = await store.read();

      expect(loaded, isNotNull);
      expect(loaded, hasLength(2));
      expect(loaded!.first.id, 'az-900');
      expect(loaded.first.blueprintDate, '2026-07-20');
      expect(loaded.first.domains.single.weightLabel, '25–30%');
      expect(loaded.first.studyGuideUrl, startsWith('https://learn.microsoft.com/'));
      expect(loaded.last.id, 'sc-900');
    });

    test('returns null on invalid persisted payload', () async {
      String? persisted = '{"not":"a list"}';
      final JsonCatalogCacheStore store = JsonCatalogCacheStore(
        read: () async => persisted,
        write: (String json) async => persisted = json,
      );

      final List<TrackSummary>? loaded = await store.read();
      expect(loaded, isNull);
    });

    test('preserves replacement and navigation metadata', () {
      final TrackSummary track = TrackSummary.fromJson(<String, dynamic>{
        'id': 'ai-901',
        'code': 'AI-901',
        'learningAvailable': false,
        'replacementCode': '',
        'migrationNote': 'AI-901 remplace AI-900.',
      });

      expect(track.learningAvailable, isFalse);
      expect(track.migrationNote, contains('AI-900'));
      expect(track.toJson()['learningAvailable'], isFalse);
    });
  });
}
