import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/lesson/application/lesson_feedback.dart';

/// Root dependency wiring for the app, expressed as Riverpod providers.
///
/// This is the composition layer: it constructs the [ApiClient] and the
/// concrete repositories, then exposes them as abstractions so feature
/// controllers depend only on interfaces. Swapping a repo for a fake in tests
/// is a one-line `overrideWithValue`.

/// Supplies the current access token to the API client.
///
/// Delegates to the auth controller: in dev (Entra not configured) it returns
/// the dev bearer token so the app works end-to-end; once Entra External ID is
/// configured it returns a real, proactively-refreshed access token.
final tokenProvider = Provider<TokenProvider>((Ref ref) {
  return ref.watch(authControllerProvider.notifier).currentAccessToken;
});

final apiClientProvider = Provider<ApiClient>((Ref ref) {
  final AuthController auth = ref.watch(authControllerProvider.notifier);
  return ApiClient(
    tokenProvider: ref.watch(tokenProvider),
    onUnauthorized: auth.handleUnauthorized,
  );
});

final userRepositoryProvider = Provider<UserRepository>(
  (Ref ref) => RemoteUserRepository(ref.watch(apiClientProvider)),
);

final pathRepositoryProvider = Provider<PathRepository>(
  (Ref ref) => RemotePathRepository(ref.watch(apiClientProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (Ref ref) => RemoteCatalogRepository(ref.watch(apiClientProvider)),
);

final lessonRepositoryProvider = Provider<LessonRepository>(
  (Ref ref) => RemoteLessonRepository(ref.watch(apiClientProvider)),
);

/// Persistent queue of idempotent offline actions.
///
/// Defaults to an in-memory store so widget tests need no platform channels;
/// [bootstrap] overrides it with a SharedPreferences-backed store so a queued
/// submission survives an app restart on iOS and Android.
final syncStoreProvider = Provider<SyncQueueStore>(
  (Ref ref) => InMemorySyncQueueStore(),
);

/// The offline-first sync engine. Replays queued submissions through the API
/// with idempotent keys, exponential backoff and dead-lettering. A single
/// long-lived instance per app session, flushed on reconnect/resume/startup by
/// `OfflineSyncScope`.
final syncEngineProvider = Provider<SyncEngine>((Ref ref) {
  final SyncEngine engine = SyncEngine(
    store: ref.watch(syncStoreProvider),
    sender: apiSyncSender(ref.watch(apiClientProvider)),
  );
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

/// Quiz submissions go through an offline decorator: an attempt that fails on a
/// transient error (offline, 5xx, 429) is enqueued and replayed later, keyed by
/// its `clientAttemptId`, so a finished lesson is never lost. Permanent
/// failures pass straight through to the caller unchanged.
final quizRepositoryProvider = Provider<QuizRepository>(
  (Ref ref) => OfflineQuizRepository(
    RemoteQuizRepository(ref.watch(apiClientProvider)),
    ref.watch(syncEngineProvider),
  ),
);

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (Ref ref) => RemoteLeaderboardRepository(ref.watch(apiClientProvider)),
);

final tutorRepositoryProvider = Provider<TutorRepository>(
  (Ref ref) => RemoteTutorRepository(ref.watch(apiClientProvider)),
);

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (Ref ref) => RemoteRecommendationRepository(ref.watch(apiClientProvider)),
);

/// User-controlled theme mode (persisted by settings later). System by default.
final themeModeProvider = StateProvider<ThemeMode>((Ref ref) => ThemeMode.system);

/// Audio-haptic feedback for lesson checks (§3.14). Real haptics by default;
/// tests / reduce-motion override this with [SilentLessonFeedback].
final lessonFeedbackProvider = Provider<LessonFeedback>(
  (Ref ref) => const HapticLessonFeedback(),
);

/// Unwraps a repository [Result] into a plain value, throwing the [Failure] so
/// Riverpod surfaces it as `AsyncError` for the UI's `.when(error: …)` branch.
T _orThrow<T>(Result<T> result) =>
    result.when(success: (T value) => value, failure: (Failure f) => throw f);

/// The signed-in learner's profile. Auto-disposed and shared by Home + Profile.
final meProvider = FutureProvider.autoDispose<UserProfile>((Ref ref) async {
  return _orThrow(await ref.watch(userRepositoryProvider).getMe());
});

/// A learner's path through one certification track, keyed by trackId.
final pathProvider = FutureProvider.autoDispose.family<LearningPath, String>(
  (Ref ref, String trackId) async {
    return _orThrow(await ref.watch(pathRepositoryProvider).getPath(trackId));
  },
);

/// The certification track currently shown on the Path screen. Switching it in
/// the course picker re-points the whole primary tab, Duolingo-style. Defaults
/// to AZ-900, the app's flagship track.
final activeTrackProvider = StateProvider<String>((Ref ref) => 'az-900');

/// The catalog of certification tracks the app offers, for the course picker.
/// Auto-disposed: it is only loaded while the picker sheet is open.
final catalogProvider = FutureProvider.autoDispose<List<TrackSummary>>((Ref ref) async {
  return _orThrow(await ref.watch(catalogRepositoryProvider).getCatalog());
});

/// The "next best action" coach for one track: a server-ranked shelf of what
/// the learner should do next. Auto-disposed and keyed by trackId so Home can
/// surface a coaching section without recomputing anything on-device.
final nextBestProvider = FutureProvider.autoDispose.family<NextBest, String>(
  (Ref ref, String trackId) async {
    return _orThrow(await ref.watch(recommendationRepositoryProvider).getNextBest(trackId));
  },
);

/// The learner's current weekly league standings.
final leagueProvider = FutureProvider.autoDispose<League>((Ref ref) async {
  return _orThrow(await ref.watch(leaderboardRepositoryProvider).getMyLeague());
});
