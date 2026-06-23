import 'package:data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for the offline action queue. Versioned so a future schema
/// change can migrate or discard old payloads cleanly.
const String kSyncQueuePrefsKey = 'microlingo.sync.queue.v1';

/// Builds a [JsonSyncQueueStore] persisted in [SharedPreferences] under a
/// single string key, so the offline action queue survives app restarts on
/// iOS and Android.
///
/// The read/write closures are async and the engine only invokes them when it
/// loads or mutates the queue — never at construction — so wiring this provider
/// stays cheap and touches no platform channel until there is real work to do.
JsonSyncQueueStore prefsSyncQueueStore(SharedPreferences prefs) {
  return JsonSyncQueueStore(
    read: () async => prefs.getString(kSyncQueuePrefsKey),
    write: (String json) async {
      await prefs.setString(kSyncQueuePrefsKey, json);
    },
  );
}
