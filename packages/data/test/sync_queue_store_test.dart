import 'dart:convert';

import 'package:data/data.dart';
import 'package:test/test.dart';

SyncAction _action(String id, DateTime createdAt) => SyncAction(
      id: id,
      kind: 'quizSubmit',
      endpoint: '/quiz/$id/submit',
      payload: <String, dynamic>{'id': id},
      idempotencyKey: id,
      createdAt: createdAt,
      ownerId: 'person-1',
    );

void main() {
  test('partial corruption is quarantined while healthy entries preserve order', () async {
    final SyncAction first = _action('first', DateTime.utc(2026, 1, 1));
    final SyncAction second = _action('second', DateTime.utc(2026, 1, 2));
    final String raw = jsonEncode(<dynamic>[
      first.toJson(),
      <String, dynamic>{'id': 42, 'kind': 'broken', 'ownerId': 'person-1'},
      second.toJson(),
    ]);
    final List<SyncQueueCorruption> quarantined = <SyncQueueCorruption>[];
    final List<(String reason, bool persisted)> reports = <(String, bool)>[];
    final JsonSyncQueueStore store = JsonSyncQueueStore(
      read: () async => raw,
      write: (_) async {},
      quarantine: (SyncQueueCorruption corruption) async {
        quarantined.add(corruption);
        return true;
      },
      onCorruption: (SyncQueueCorruption corruption, {required bool persisted}) {
        reports.add((corruption.reason, persisted));
      },
    );

    final List<SyncAction> actions = await store.load();

    expect(actions.map((SyncAction action) => action.id), <String>['first', 'second']);
    expect(quarantined, hasLength(1));
    expect(quarantined.single.index, 1);
    expect(quarantined.single.ownerId, 'person-1');
    expect(reports, <(String, bool)>[('entry-type', true)]);
  });

  test('failed quarantine persistence is reported and retried without blocking healthy work',
      () async {
    final SyncAction healthy = _action('healthy', DateTime.utc(2026));
    String raw = jsonEncode(<dynamic>[
      <String, dynamic>{'id': 'broken'},
      healthy.toJson(),
    ]);
    var attempts = 0;
    final List<bool> persistedReports = <bool>[];
    JsonSyncQueueStore makeStore() => JsonSyncQueueStore(
          read: () async => raw,
          write: (String value) async {
            raw = value;
          },
          quarantine: (_) async {
            attempts++;
            return attempts > 1;
          },
          onCorruption: (_, {required bool persisted}) {
            persistedReports.add(persisted);
          },
        );

    final JsonSyncQueueStore firstStore = makeStore();
    final List<SyncAction> firstLoad = await firstStore.load();
    await firstStore.save(firstLoad);
    expect(jsonDecode(raw), hasLength(2));

    final JsonSyncQueueStore retryStore = makeStore();
    final List<SyncAction> retriedLoad = await retryStore.load();
    await retryStore.save(retriedLoad);

    expect(firstLoad.single.id, 'healthy');
    expect(retriedLoad.single.id, 'healthy');
    expect(jsonDecode(raw), hasLength(1));
    expect(attempts, 2);
    expect(persistedReports, <bool>[false, true]);
  });

  test('malformed root is quarantined explicitly instead of silently discarded', () async {
    SyncQueueCorruption? quarantined;
    bool? persistedResult;
    final JsonSyncQueueStore store = JsonSyncQueueStore(
      read: () async => '{"incomplete"',
      write: (_) async {},
      quarantine: (SyncQueueCorruption corruption) async {
        quarantined = corruption;
        return true;
      },
      onCorruption: (_, {required bool persisted}) {
        persistedResult = persisted;
      },
    );

    final List<SyncAction> actions = await store.load();

    expect(actions, isEmpty);
    expect(quarantined!.reason, 'invalid-json');
    expect(persistedResult, isTrue);
  });

  test('failed root quarantine retains raw data without blocking new healthy actions', () async {
    String raw = '{"incomplete"';
    final JsonSyncQueueStore firstStore = JsonSyncQueueStore(
      read: () async => raw,
      write: (String value) async {
        raw = value;
      },
      quarantine: (_) async => false,
    );
    expect(await firstStore.load(), isEmpty);
    final SyncAction healthy = _action('healthy', DateTime.utc(2026));

    await firstStore.save(<SyncAction>[healthy]);

    final List<dynamic> retained = jsonDecode(raw) as List<dynamic>;
    expect(retained, hasLength(2));
    expect((retained.first as Map<String, dynamic>)['id'], 'healthy');

    final JsonSyncQueueStore retryStore = JsonSyncQueueStore(
      read: () async => raw,
      write: (String value) async {
        raw = value;
      },
      quarantine: (_) async => true,
    );
    final List<SyncAction> recovered = await retryStore.load();
    await retryStore.save(recovered);

    expect(recovered.single.id, 'healthy');
    expect(jsonDecode(raw), hasLength(1));
  });

  test('owner deletion removes retained corrupt entries only for that owner', () async {
    final SyncAction personB = _action('person-b', DateTime.utc(2026));
    String raw = jsonEncode(<dynamic>[
      <String, dynamic>{'id': 42, 'ownerId': 'person-a'},
      personB.toJson()..['ownerId'] = 'person-b',
    ]);
    final JsonSyncQueueStore store = JsonSyncQueueStore(
      read: () async => raw,
      write: (String value) async {
        raw = value;
      },
      quarantine: (_) async => false,
    );
    final List<SyncAction> actions = await store.load();

    store.discardRetainedOwner('person-a');
    await store.save(actions);

    final List<dynamic> persisted = jsonDecode(raw) as List<dynamic>;
    expect(persisted, hasLength(1));
    expect((persisted.single as Map<String, dynamic>)['ownerId'], 'person-b');
  });
}
