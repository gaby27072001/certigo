import 'package:core/core.dart';

import '../api/api_client.dart';
import 'sync_action.dart';
import 'sync_dispatcher.dart';

/// Builds a [SyncSender] that replays a queued action through the [ApiClient].
///
/// The response body is intentionally ignored: on replay the action has already
/// taken effect server-side (idempotency dedupe), and the app re-fetches the
/// authoritative profile/state via `/me`. We only care whether the call
/// succeeded, was transiently rejected, or is permanently dead — which
/// [classifyFailure] decides from the typed [Failure].
SyncSender apiSyncSender(ApiClient api) {
  return (SyncAction action) async {
    final Result<Map<String, dynamic>> result = await api.postJson<Map<String, dynamic>>(
      action.endpoint,
      action.payload,
      (Map<String, dynamic> json) => json,
    );
    return result.when(success: (_) => SyncDispatch.success, failure: classifyFailure);
  };
}
