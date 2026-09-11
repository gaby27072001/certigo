import 'package:certigo/app/offline/offline_sync_scope.dart';
import 'package:certigo/app/session_resume_store.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline mutations flush only for an authenticated session', () {
    expect(canFlushOfflineActions(const AuthLoading()), isFalse);
    expect(canFlushOfflineActions(const AuthSigningOut()), isFalse);
    expect(canFlushOfflineActions(const Unauthenticated()), isFalse);
    expect(
      canFlushOfflineActions(
        const Authenticated(
          AuthSession(accessToken: 'token', userId: 'user-1'),
        ),
      ),
      isTrue,
    );
  });

  group('resume records retired by the queue', () {
    /// The queue can settle an attempt while the learner never reopens the
    /// quiz: the app restarts, connectivity returns, `SyncEngine` replays the
    /// submission and the server accepts it. The record that outlived the
    /// crash has to be retired then, or reopening the lesson later resumes a
    /// run the server has already graded.
    ///
    /// No points are at stake either way — `QuizService` returns the stored
    /// result for a known key — so this is about not making a learner replay a
    /// run for nothing.
    SessionResumeRecord record(String attemptId, {ResumeSurface? surface}) => SessionResumeRecord(
          surface: surface ?? ResumeSurface.quiz,
          ownerId: 'user-1',
          sessionId: 'az-900/l1',
          publicManifestId: 'pm-1',
          clientAttemptId: attemptId,
          startedAt: DateTime.utc(2026, 9, 11),
          progress: const <String, dynamic>{'index': 1},
        );

    SyncAction action(String key, SyncActionStatus status) => SyncAction(
          id: 'a-$key',
          kind: 'quizSubmit',
          endpoint: '/quiz/l1/submit',
          payload: const <String, dynamic>{},
          idempotencyKey: key,
          createdAt: DateTime.utc(2026, 9, 11),
          status: status,
        );

    test('a delivered attempt retires its record', () async {
      final InMemorySessionResumeStore store = InMemorySessionResumeStore();
      await store.write(record('key-x'));

      expect(
        resumeSurfacesSettledByQueue(
          store: store,
          actions: <SyncAction>[action('key-x', SyncActionStatus.done)],
        ),
        <ResumeSurface>[ResumeSurface.quiz],
      );
    });

    test('an attempt still in flight keeps its record', () async {
      final InMemorySessionResumeStore store = InMemorySessionResumeStore();
      await store.write(record('key-x'));

      expect(
        resumeSurfacesSettledByQueue(
          store: store,
          actions: <SyncAction>[action('key-x', SyncActionStatus.pending)],
        ),
        isEmpty,
        reason: 'the server has not ruled, so the session is still the learner’s',
      );
    });

    test('a dead-lettered attempt keeps its record', () async {
      final InMemorySessionResumeStore store = InMemorySessionResumeStore();
      await store.write(record('key-x'));

      expect(
        resumeSurfacesSettledByQueue(
          store: store,
          actions: <SyncAction>[action('key-x', SyncActionStatus.dead)],
        ),
        isEmpty,
        reason: 'nothing was applied server-side, so the learner may still finish '
            'under the same key',
      );
    });

    test('another session’s delivery does not retire this record', () async {
      final InMemorySessionResumeStore store = InMemorySessionResumeStore();
      await store.write(record('key-x'));

      expect(
        resumeSurfacesSettledByQueue(
          store: store,
          actions: <SyncAction>[action('key-other', SyncActionStatus.done)],
        ),
        isEmpty,
      );
    });

    test('each surface is retired independently', () async {
      final InMemorySessionResumeStore store = InMemorySessionResumeStore();
      await store.write(record('key-quiz'));
      await store.write(record('key-lesson', surface: ResumeSurface.lesson));

      expect(
        resumeSurfacesSettledByQueue(
          store: store,
          actions: <SyncAction>[action('key-lesson', SyncActionStatus.done)],
        ),
        <ResumeSurface>[ResumeSurface.lesson],
        reason: 'settling a lesson must not discard a quiz left in progress',
      );
    });
  });
}
