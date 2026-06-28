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
        _track(
          id: 'sc-900',
          code: 'SC-900',
          title: 'Microsoft Security Fundamentals',
        ),
      ]);

      final List<TrackSummary>? loaded = await store.read();

      expect(loaded, isNotNull);
      expect(loaded, hasLength(2));
      expect(loaded!.first.id, 'az-900');
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
  });
}
