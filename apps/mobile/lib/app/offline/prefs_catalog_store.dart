import 'package:data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for the offline catalog cache.
const String kCatalogCachePrefsKey = 'microlingo.catalog.cache.v1';

/// Builds a [JsonCatalogCacheStore] persisted in [SharedPreferences] under one
/// string key so the track catalog survives app restarts.
JsonCatalogCacheStore prefsCatalogCacheStore(SharedPreferences prefs) {
  return JsonCatalogCacheStore(
    read: () async => prefs.getString(kCatalogCachePrefsKey),
    write: (String json) async {
      await prefs.setString(kCatalogCachePrefsKey, json);
    },
  );
}
