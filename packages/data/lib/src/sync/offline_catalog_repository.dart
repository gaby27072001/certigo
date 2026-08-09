import 'package:core/core.dart';

import '../models/track_summary.dart';
import '../repositories/repositories.dart';
import 'catalog_cache_store.dart';
import 'sync_dispatcher.dart';

/// A [CatalogRepository] decorator that serves a persistent catalog offline.
///
/// On remote success, it refreshes the local cache. On transient failures
/// (network, auth refresh windows, 5xx/429), it falls back to the last cached
/// catalog snapshot when available. Permanent failures are propagated unchanged.
class OfflineCatalogRepository implements CatalogRepository {
  OfflineCatalogRepository(this._inner, this._cacheStore);

  final CatalogRepository _inner;
  final CatalogCacheStore _cacheStore;

  @override
  Future<Result<List<TrackSummary>>> getCatalog() async {
    final Result<List<TrackSummary>> result = await _inner.getCatalog();

    if (result case Success<List<TrackSummary>>(:final List<TrackSummary> value)) {
      await _cacheStore.write(value);
      return result;
    }

    final Failure failure = (result as Err<List<TrackSummary>>).failure;
    if (classifyFailure(failure) == SyncDispatch.retryable) {
      final List<TrackSummary>? cached = await _cacheStore.read();
      if (cached != null) return Success<List<TrackSummary>>(cached);
    }

    return result;
  }
}
