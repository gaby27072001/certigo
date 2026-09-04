import 'package:data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kContentReleaseCachePrefsPrefix = 'certigo.content.release.cache.v1.';

JsonContentReleaseCacheStore prefsContentReleaseCacheStore(SharedPreferences prefs) {
  String key(String suffix) => '$kContentReleaseCachePrefsPrefix$suffix';

  return JsonContentReleaseCacheStore(
    read: (String suffix) async => prefs.getString(key(suffix)),
    write: (String suffix, String value) async {
      if (!await prefs.setString(key(suffix), value)) {
        throw const ContentReleaseCacheException(
          'SharedPreferences refused the offline content cache write.',
        );
      }
    },
  );
}
