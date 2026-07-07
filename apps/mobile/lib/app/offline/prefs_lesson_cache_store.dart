import 'package:data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for the offline lesson cache.
const String kLessonCachePrefsKey = 'certigo.lesson.cache.v1';

/// Builds a [JsonLessonCacheStore] persisted in [SharedPreferences] under one
/// string key so downloaded study sessions survive app restarts and stay
/// readable offline.
///
/// The store is manifest-version-aware: content cached under a previous manifest
/// version is treated as a miss and purged on the next write, which is how the
/// offline cache is invalidated when the content manifest changes.
JsonLessonCacheStore prefsLessonCacheStore(SharedPreferences prefs) {
  return JsonLessonCacheStore(
    read: () async => prefs.getString(kLessonCachePrefsKey),
    write: (String json) async {
      await prefs.setString(kLessonCachePrefsKey, json);
    },
  );
}
