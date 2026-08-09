import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

class _ScriptedCatalogRepository implements CatalogRepository {
  _ScriptedCatalogRepository(this.result);

  final Result<List<TrackSummary>> result;

  @override
  Future<Result<List<TrackSummary>>> getCatalog() async => result;
}

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
  group('OfflineCatalogRepository', () {
    test('returns remote success unchanged and refreshes cache', () async {
      final List<TrackSummary> remoteTracks = <TrackSummary>[_track()];
      final _ScriptedCatalogRepository inner = _ScriptedCatalogRepository(
        Success<List<TrackSummary>>(remoteTracks),
      );
      final InMemoryCatalogCacheStore store = InMemoryCatalogCacheStore();
      final OfflineCatalogRepository repo = OfflineCatalogRepository(inner, store);

      final Result<List<TrackSummary>> result = await repo.getCatalog();
      final List<TrackSummary>? cached = await store.read();

      expect(result.isSuccess, isTrue);
      expect((result as Success<List<TrackSummary>>).value, hasLength(1));
      expect(cached, isNotNull);
      expect(cached!.single.id, 'az-900');
    });

    test('falls back to cached catalog on transient failure', () async {
      final _ScriptedCatalogRepository inner = _ScriptedCatalogRepository(
        const Err<List<TrackSummary>>(NetworkFailure()),
      );
      final InMemoryCatalogCacheStore store = InMemoryCatalogCacheStore(<TrackSummary>[
        _track(id: 'dp-900', code: 'DP-900', title: 'Microsoft Azure Data Fundamentals'),
      ]);
      final OfflineCatalogRepository repo = OfflineCatalogRepository(inner, store);

      final Result<List<TrackSummary>> result = await repo.getCatalog();

      expect(result.isSuccess, isTrue);
      final List<TrackSummary> tracks = (result as Success<List<TrackSummary>>).value;
      expect(tracks.single.id, 'dp-900');
    });

    test('returns original transient failure when cache is absent', () async {
      final _ScriptedCatalogRepository inner = _ScriptedCatalogRepository(
        const Err<List<TrackSummary>>(NetworkFailure()),
      );
      final InMemoryCatalogCacheStore store = InMemoryCatalogCacheStore();
      final OfflineCatalogRepository repo = OfflineCatalogRepository(inner, store);

      final Result<List<TrackSummary>> result = await repo.getCatalog();

      expect(result.isFailure, isTrue);
      expect((result as Err<List<TrackSummary>>).failure, isA<NetworkFailure>());
    });

    test('returns original permanent failure even when cache exists', () async {
      final _ScriptedCatalogRepository inner = _ScriptedCatalogRepository(
        const Err<List<TrackSummary>>(NotFoundFailure()),
      );
      final InMemoryCatalogCacheStore store = InMemoryCatalogCacheStore(<TrackSummary>[_track()]);
      final OfflineCatalogRepository repo = OfflineCatalogRepository(inner, store);

      final Result<List<TrackSummary>> result = await repo.getCatalog();

      expect(result.isFailure, isTrue);
      expect((result as Err<List<TrackSummary>>).failure, isA<NotFoundFailure>());
    });
  });
}
