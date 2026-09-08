import 'dart:convert';

import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for the offline action queue. Versioned so a future schema
/// change can migrate or discard old payloads cleanly.
const String kSyncQueuePrefsKey = 'certigo.sync.queue.v1';
const String kSyncQueueQuarantinePrefsPrefix = 'certigo.sync.queue.quarantine.v1';

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
      final bool saved = await prefs.setString(kSyncQueuePrefsKey, json);
      if (!saved) {
        throw StateError('Unable to persist the offline synchronization queue.');
      }
    },
    quarantine: (SyncQueueCorruption corruption) async {
      try {
        return await prefs.setString(
          '$kSyncQueueQuarantinePrefsPrefix.${corruption.fingerprint}',
          jsonEncode(corruption.toJson()),
        );
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    },
    onCorruption: (SyncQueueCorruption corruption, {required bool persisted}) {
      debugPrint(
        '[sync-queue] quarantined reason=${corruption.reason} '
        'index=${corruption.index ?? -1} fingerprint=${corruption.fingerprint} '
        'persisted=$persisted',
      );
    },
  );
}
