import 'package:data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Legacy key used before the rename to Certigo. Kept only so the builder below
/// can remove any stale data left in SharedPreferences on existing devices.
const String _kLegacyCatalogCachePrefsKey = 'microlingo.catalog.cache.v1';

/// Storage key for the offline catalog cache.
const String kCatalogCachePrefsKey = 'certigo.catalog.cache.v1';

/// Builds a [JsonCatalogCacheStore] persisted in [SharedPreferences] under one
/// string key so the track catalog survives app restarts.
///
/// On first call after an app update, the legacy [_kLegacyCatalogCachePrefsKey]
/// entry (if present) is removed so SharedPreferences does not accumulate stale
/// data. The cache itself is a network optimisation, so a one-time miss on
/// upgrade is acceptable.
JsonCatalogCacheStore prefsCatalogCacheStore(SharedPreferences prefs) {
  // Clean up the stale key from before the rename; fire-and-forget is fine here
  // because this is a cache and a miss simply triggers a fresh network fetch.
  if (prefs.containsKey(_kLegacyCatalogCachePrefsKey)) {
    prefs.remove(_kLegacyCatalogCachePrefsKey);
  }

  return JsonCatalogCacheStore(
    read: () async => prefs.getString(kCatalogCachePrefsKey),
    write: (String json) async {
      await prefs.setString(kCatalogCachePrefsKey, json);
    },
  );
}
