import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('SyncAction', () {
    test('round-trips through JSON with all fields incl nested payload', () {
      final SyncAction action = SyncAction(
        id: 'a1',
        kind: 'quizSubmit',
        endpoint: '/quiz/L1/submit',
        payload: <String, dynamic>{
          'clientAttemptId': 'k1',
          'answers': <dynamic>[
            <String, dynamic>{
              'itemId': 'i1',
              'selected': <String>['o1'],
            },
          ],
        },
        idempotencyKey: 'k1',
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        status: SyncActionStatus.pending,
        attempts: 2,
        nextAttemptAt: DateTime.utc(2026, 1, 2, 3, 5),
        lastError: 'retryable',
      );

      final SyncAction back = SyncAction.fromJson(action.toJson());

      expect(back.id, 'a1');
      expect(back.kind, 'quizSubmit');
      expect(back.endpoint, '/quiz/L1/submit');
      expect(back.idempotencyKey, 'k1');
      expect(back.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(back.status, SyncActionStatus.pending);
      expect(back.attempts, 2);
      expect(back.nextAttemptAt, DateTime.utc(2026, 1, 2, 3, 5));
      expect(back.lastError, 'retryable');
      expect(back.completedAt, isNull);
      expect(back.payload['clientAttemptId'], 'k1');
      final List<dynamic> answers = back.payload['answers'] as List<dynamic>;
      expect((answers.first as Map<dynamic, dynamic>)['itemId'], 'i1');
    });

    test('fromJson applies tolerant defaults for a minimal record', () {
      final SyncAction minimal = SyncAction.fromJson(<String, dynamic>{
        'id': 'a',
        'kind': 'k',
        'endpoint': '/e',
        'payload': <String, dynamic>{},
        'idempotencyKey': 'key',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });

      expect(minimal.status, SyncActionStatus.pending);
      expect(minimal.attempts, 0);
      expect(minimal.nextAttemptAt, isNull);
      expect(minimal.lastError, isNull);
      expect(minimal.completedAt, isNull);
    });

    test('copyWith clear flags null-out optionals', () {
      final SyncAction action = SyncAction(
        id: 'a',
        kind: 'k',
        endpoint: '/e',
        payload: const <String, dynamic>{},
        idempotencyKey: 'key',
        createdAt: DateTime.utc(2026),
        nextAttemptAt: DateTime.utc(2026, 1, 1, 1),
        lastError: 'oops',
        completedAt: DateTime.utc(2026, 1, 1, 2),
      );

      final SyncAction cleared = action.copyWith(
        clearNextAttemptAt: true,
        clearLastError: true,
        clearCompletedAt: true,
      );

      expect(cleared.nextAttemptAt, isNull);
      expect(cleared.lastError, isNull);
      expect(cleared.completedAt, isNull);
      // Unrelated fields preserved.
      expect(cleared.id, 'a');
      expect(cleared.idempotencyKey, 'key');
    });

    test('isDue reflects status and backoff gate', () {
      final DateTime now = DateTime.utc(2026, 5, 1, 12);
      final SyncAction immediate = SyncAction(
        id: 'a',
        kind: 'k',
        endpoint: '/e',
        payload: const <String, dynamic>{},
        idempotencyKey: 'k',
        createdAt: now,
      );
      expect(immediate.isDue(now), isTrue);

      final SyncAction gated =
          immediate.copyWith(nextAttemptAt: now.add(const Duration(seconds: 10)));
      expect(gated.isDue(now), isFalse);
      expect(gated.isDue(now.add(const Duration(seconds: 10))), isTrue);

      final SyncAction done = immediate.copyWith(status: SyncActionStatus.done);
      expect(done.isDue(now), isFalse);

      final SyncAction dead = immediate.copyWith(status: SyncActionStatus.dead);
      expect(dead.isDue(now), isFalse);
    });
  });
}
