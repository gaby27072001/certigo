import 'package:certigo/app/active_track_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('pending selection round-trips atomically with owner and base track', () async {
    final SharedPreferencesActiveTrackStore store =
        SharedPreferencesActiveTrackStore(await SharedPreferences.getInstance());
    const ActiveTrackRecord pending = ActiveTrackRecord(
      trackId: 'sc-900',
      ownerId: 'user-1',
      pendingMutationId: 'mutation-1',
      pendingBaseTrackId: 'dp-900',
      pendingPredecessors: <String>['ai-901'],
    );

    await store.write(pending);
    final ActiveTrackRecord? restored = SharedPreferencesActiveTrackStore(
      await SharedPreferences.getInstance(),
    ).read();

    expect(restored?.trackId, 'sc-900');
    expect(restored?.ownerId, 'user-1');
    expect(restored?.pendingMutationId, 'mutation-1');
    expect(restored?.pendingBaseTrackId, 'dp-900');
    expect(restored?.pendingPredecessors, <String>['ai-901']);
    expect(restored?.isPending, isTrue);
  });
}
