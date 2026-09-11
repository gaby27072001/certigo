import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';

import 'active_track_store.dart';
import 'content/runtime_content_dependencies.dart';
import 'session_resume_store.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
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
    debugLog: debugPrint,
  );
});

final userRepositoryProvider = Provider<UserRepository>(
  (Ref ref) => RemoteUserRepository(ref.watch(apiClientProvider)),
);

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (Ref ref) => RemoteAccountDeletionRepository(ref.watch(apiClientProvider)),
);

final pathRepositoryProvider = Provider<PathRepository>(
  (Ref ref) => RemotePathRepository(ref.watch(apiClientProvider)),
);

final catalogStoreProvider = Provider<CatalogCacheStore>((Ref ref) => InMemoryCatalogCacheStore());

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (Ref ref) => OfflineCatalogRepository(
    RemoteCatalogRepository(ref.watch(apiClientProvider)),
    ref.watch(catalogStoreProvider),
  ),
);

/// Opt-in feature flag for the offline study cache (wp-p1-08).
///
/// Defaults to `false`: online-only is the default behaviour. Compile with
/// `--dart-define=OFFLINE_STUDY_CACHE=true` to make study sessions downloadable
/// and readable offline. Rollback is simply not enabling the flag.
final offlineStudyCacheEnabledProvider = Provider<bool>(
  (Ref ref) => const bool.fromEnvironment('OFFLINE_STUDY_CACHE', defaultValue: false),
);

/// Current content manifest version, used as the single cache-invalidation key
/// for the offline lesson cache. Bumping it (via
/// `--dart-define=CONTENT_MANIFEST_VERSION=...`) invalidates every cached lesson.
final contentManifestVersionProvider = Provider<String>(
  (Ref ref) => const String.fromEnvironment('CONTENT_MANIFEST_VERSION', defaultValue: 'v1'),
);

/// Backing store for the offline lesson cache. Defaults to in-memory so tests
/// need no platform channels; [bootstrap] overrides it with a
/// SharedPreferences-backed store so downloaded lessons survive app restarts.
final lessonStoreProvider = Provider<LessonCacheStore>((Ref ref) => InMemoryLessonCacheStore());

final lessonRepositoryProvider = Provider<LessonRepository>((Ref ref) {
  LessonRepository repository = RemoteLessonRepository(ref.watch(apiClientProvider));
  if (ref.watch(offlineStudyCacheEnabledProvider)) {
    repository = OfflineLessonRepository(
      repository,
      ref.watch(lessonStoreProvider),
      ref.watch(contentManifestVersionProvider),
    );
  }
  if (!ref.watch(runtimeContentSyncEnabledProvider)) return repository;
  return RuntimeContentLessonRepository(
    inner: repository,
    store: ref.watch(runtimeContentStoreProvider),
    pins: ref.watch(runtimeContentPinRegistryProvider),
    ownerIdProvider: () {
      final AuthState auth = ref.read(authControllerProvider);
      return auth is Authenticated ? auth.session.userId : null;
    },
  );
});

/// Persistent queue of idempotent offline actions.
///
/// Defaults to an in-memory store so widget tests need no platform channels;
/// [bootstrap] overrides it with a SharedPreferences-backed store so a queued
/// submission survives an app restart on iOS and Android.
final syncStoreProvider = Provider<SyncQueueStore>((Ref ref) => InMemorySyncQueueStore());

/// The offline-first sync engine. Replays queued submissions through the API
/// with idempotent keys, exponential backoff and dead-lettering. A single
/// long-lived instance per app session, flushed on reconnect/resume/startup by
/// `OfflineSyncScope`.
final syncEngineProvider = Provider<SyncEngine>((Ref ref) {
  final SyncEngine engine = SyncEngine(
    store: ref.watch(syncStoreProvider),
    sender: apiSyncSender(ref.watch(apiClientProvider)),
    ownerIdProvider: () {
      final AuthState auth = ref.read(authControllerProvider);
      return auth is Authenticated ? auth.session.userId : null;
    },
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

final seasonRepositoryProvider = Provider<SeasonRepository>(
  (Ref ref) => RemoteSeasonRepository(ref.watch(apiClientProvider)),
);

final questRepositoryProvider = Provider<QuestRepository>(
  (Ref ref) => RemoteQuestRepository(ref.watch(apiClientProvider)),
);

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (Ref ref) => RemoteAchievementRepository(ref.watch(apiClientProvider)),
);

final shopRepositoryProvider = Provider<ShopRepository>(
  (Ref ref) => RemoteShopRepository(ref.watch(apiClientProvider)),
);

final friendRepositoryProvider = Provider<FriendRepository>(
  (Ref ref) => RemoteFriendRepository(ref.watch(apiClientProvider)),
);

final shareCardRepositoryProvider = Provider<ShareCardRepository>(
  (Ref ref) => RemoteShareCardRepository(ref.watch(apiClientProvider)),
);

final examRepositoryProvider = Provider<ExamRepository>(
  (Ref ref) => RemoteExamRepository(ref.watch(apiClientProvider)),
);

/// User-controlled theme mode (persisted by settings later). System by default.
final themeModeProvider = StateProvider<ThemeMode>((Ref ref) => ThemeMode.system);

/// Audio-haptic feedback for lesson checks (§3.14). Real haptics by default;
/// tests / reduce-motion override this with [SilentLessonFeedback].
final lessonFeedbackProvider = Provider<LessonFeedback>((Ref ref) => const HapticLessonFeedback());

/// Persistent local cache for the learner's selected certification.
///
/// Bootstrap replaces the in-memory default with SharedPreferences.
final activeTrackStoreProvider = Provider<ActiveTrackStore>(
  (Ref ref) => InMemoryActiveTrackStore(),
);

/// Where an interrupted learning session is kept so it can be resumed after
/// iOS kills the app.
///
/// Defaults to an in-memory store so widget tests need no platform channels;
/// [bootstrap] overrides it with a SharedPreferences-backed store, which is
/// what actually survives a process death. The record carries the session's
/// `clientAttemptId`, so a resumed submission resolves to the same server
/// attempt instead of being counted as a second one.
final sessionResumeStoreProvider = Provider<SessionResumeStore>(
  (Ref ref) => InMemorySessionResumeStore(),
);

final activeTrackOwnerIdProvider = Provider<String?>((Ref ref) {
  final AuthState auth = ref.watch(authControllerProvider);
  return auth is Authenticated ? auth.session.userId : null;
});

final activeTrackAuthenticatedProvider = Provider<bool>(
  (Ref ref) => ref.watch(authControllerProvider) is Authenticated,
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
final pathProvider = FutureProvider.autoDispose.family<LearningPath, String>((
  Ref ref,
  String trackId,
) async {
  return _orThrow(await ref.watch(pathRepositoryProvider).getPath(trackId));
});

enum ActiveTrackSaveStatus { synced, queued, rejected }

class ActiveTrackSaveResult {
  const ActiveTrackSaveResult(this.status, [this.failure]);

  final ActiveTrackSaveStatus status;
  final Failure? failure;

  bool get accepted => status != ActiveTrackSaveStatus.rejected;
}

class MissingActiveTrackException implements Exception {
  const MissingActiveTrackException();

  @override
  String toString() => 'Aucune certification active n\'a été sélectionnée.';
}

/// Local-first active certification state.
///
/// A selection is saved to the device before the API call. Transient failures
/// remain in the same atomic record, so offline onboarding opens the selected
/// path and the account converges after authenticated connectivity returns.
class ActiveTrackController extends AsyncNotifier<String?> {
  int _selectionRevision = 0;
  bool _mutating = false;
  bool _clearRequested = false;
  Completer<void>? _mutationDone;
  String? _ownerId;

  @override
  Future<String?> build() async {
    if (_mutating) return state.asData?.value;
    final int revision = _selectionRevision;
    final ActiveTrackStore store = ref.watch(activeTrackStoreProvider);
    final ActiveTrackRecord? cached = store.read();
    final String? sessionOwner = _normalizeOwnerId(ref.watch(activeTrackOwnerIdProvider));
    final bool authenticated = sessionOwner != null || ref.watch(activeTrackAuthenticatedProvider);
    if (!authenticated) return cached?.trackId;
    if (cached != null && sessionOwner != null && cached.ownerId == sessionOwner) {
      _ownerId = cached.ownerId;
      return cached.trackId;
    }

    final Result<UserProfile> result = await ref.read(userRepositoryProvider).getMe();
    if (_selectionRevision != revision) return state.asData?.value;
    final UserProfile profile = _orThrow(result);
    final String ownerId = profile.id.trim();
    _ownerId = ownerId;
    if (cached != null && cached.ownerId == ownerId) return cached.trackId;

    final String? remote = _normalizeTrackId(profile.activeTrackId);
    if (remote != null) {
      await store.write(ActiveTrackRecord.synced(trackId: remote, ownerId: ownerId));
    } else if (cached != null) {
      await store.clear();
    }
    return _selectionRevision == revision ? remote : state.asData?.value;
  }

  Future<ActiveTrackSaveResult> select(String trackId) async {
    final String? normalized = _normalizeTrackId(trackId);
    if (normalized == null) {
      return const ActiveTrackSaveResult(
        ActiveTrackSaveStatus.rejected,
        ServerFailure('La certification sélectionnée est invalide.', statusCode: 400),
      );
    }
    if (_mutating || _clearRequested) {
      return const ActiveTrackSaveResult(
        ActiveTrackSaveStatus.rejected,
        ServerFailure('Une certification est déjà en cours d’enregistrement.', statusCode: 409),
      );
    }

    _beginMutation();
    _selectionRevision++;
    try {
      final ({String? ownerId, Failure? failure}) owner = await _resolveOwner();
      if (owner.ownerId == null) {
        return ActiveTrackSaveResult(
          ActiveTrackSaveStatus.rejected,
          owner.failure ?? const AuthFailure('Reconnecte-toi avant de choisir un parcours.'),
        );
      }

      final String ownerId = owner.ownerId!;
      final ActiveTrackStore store = ref.read(activeTrackStoreProvider);
      final ActiveTrackRecord? stored = store.read();
      final ActiveTrackRecord? previousRecord = stored?.ownerId == ownerId ? stored : null;
      final String? previous = previousRecord?.trackId ?? state.asData?.value;
      final String? baseTrackId = previousRecord != null && previousRecord.isPending
          ? previousRecord.pendingBaseTrackId
          : previous;
      final List<String> predecessors = previousRecord != null && previousRecord.isPending
          ? <String>[
              ...previousRecord.pendingPredecessors,
              if (previousRecord.trackId != normalized) previousRecord.trackId,
            ]
          : const <String>[];
      final ActiveTrackRecord pending = ActiveTrackRecord.pending(
        trackId: normalized,
        ownerId: ownerId,
        mutationId: 'active-track:$ownerId:${DateTime.now().toUtc().microsecondsSinceEpoch}',
        baseTrackId: baseTrackId,
        predecessors: predecessors,
      );

      try {
        await store.write(pending);
      } on Object catch (error, stackTrace) {
        _report(error, stackTrace, 'while persisting the selected certification');
        return const ActiveTrackSaveResult(
          ActiveTrackSaveStatus.rejected,
          CacheFailure('Impossible d\'enregistrer la certification sur cet appareil.'),
        );
      }
      state = AsyncData<String?>(normalized);

      final Result<UserProfile> result = await ref.read(userRepositoryProvider).setActiveTrack(
            trackId: normalized,
            expectedTrackId: baseTrackId,
          );
      if (_clearRequested) {
        return const ActiveTrackSaveResult(
          ActiveTrackSaveStatus.rejected,
          AuthFailure('La session a été déconnectée pendant l’enregistrement.'),
        );
      }
      return switch (result) {
        Success<UserProfile>() => await _acceptSynced(pending),
        Err<UserProfile>(:final Failure failure) => await _handleRemoteFailure(
            pending,
            previousRecord,
            failure,
          ),
      };
    } finally {
      _endMutation();
    }
  }

  Future<void> syncPending() async {
    if (_mutating || _clearRequested) return;
    final ActiveTrackStore store = ref.read(activeTrackStoreProvider);
    final ActiveTrackRecord? pending = store.read();
    if (pending == null || !pending.isPending) return;

    _beginMutation();
    _selectionRevision++;
    try {
      final ({String? ownerId, Failure? failure}) owner = await _resolveOwner();
      if (owner.ownerId == null || owner.ownerId != pending.ownerId) {
        if (owner.ownerId != null && owner.ownerId != pending.ownerId) {
          await _clearNow();
        }
        return;
      }

      state = AsyncData<String?>(pending.trackId);
      final Result<UserProfile> result = await ref.read(userRepositoryProvider).setActiveTrack(
            trackId: pending.trackId,
            expectedTrackId: pending.pendingBaseTrackId,
          );
      if (_clearRequested) return;
      switch (result) {
        case Success<UserProfile>():
          await _acceptSynced(pending);
        case Err<UserProfile>(:final Failure failure):
          if (failure is AuthFailure || classifyFailure(failure) == SyncDispatch.retryable) {
            return;
          }
          if (failure case ServerFailure(statusCode: 409)) {
            await _reconcileConflict(pending, failure);
            return;
          }
          await _restoreBase(pending, failure);
      }
    } finally {
      _endMutation();
    }
  }

  Future<({String? ownerId, Failure? failure})> _resolveOwner() async {
    final String? sessionOwner = _normalizeOwnerId(ref.read(activeTrackOwnerIdProvider));
    if (sessionOwner != null) {
      _ownerId = sessionOwner;
      return (ownerId: sessionOwner, failure: null);
    }
    if (!ref.read(activeTrackAuthenticatedProvider)) {
      return (
        ownerId: null,
        failure: const AuthFailure('Reconnecte-toi avant de choisir un parcours.'),
      );
    }

    final Result<UserProfile> result = await ref.read(userRepositoryProvider).getMe();
    return switch (result) {
      Success<UserProfile>(:final UserProfile value) => (
          ownerId: _ownerId = value.id.trim(),
          failure: null,
        ),
      Err<UserProfile>(:final Failure failure) => (ownerId: null, failure: failure),
    };
  }

  Future<ActiveTrackSaveResult> _acceptSynced(ActiveTrackRecord pending) async {
    final ActiveTrackStore store = ref.read(activeTrackStoreProvider);
    final ActiveTrackRecord? current = store.read();
    if (current?.pendingMutationId != pending.pendingMutationId) {
      return const ActiveTrackSaveResult(ActiveTrackSaveStatus.queued);
    }
    try {
      await store.write(current!.asSynced());
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace, 'while marking the certification as synchronized');
      return const ActiveTrackSaveResult(
        ActiveTrackSaveStatus.queued,
        CacheFailure('La certification sera confirmée à la prochaine synchronisation.'),
      );
    }

    state = AsyncData<String?>(pending.trackId);
    ref.invalidate(meProvider);
    return const ActiveTrackSaveResult(ActiveTrackSaveStatus.synced);
  }

  Future<ActiveTrackSaveResult> _handleRemoteFailure(
    ActiveTrackRecord pending,
    ActiveTrackRecord? previous,
    Failure failure,
  ) async {
    if (failure is AuthFailure) {
      return ActiveTrackSaveResult(ActiveTrackSaveStatus.rejected, failure);
    }
    if (failure is! AuthFailure && classifyFailure(failure) == SyncDispatch.retryable) {
      return ActiveTrackSaveResult(ActiveTrackSaveStatus.queued, failure);
    }
    if (failure case ServerFailure(statusCode: 409)) {
      return _reconcileConflict(pending, failure);
    }
    return _restore(previous, failure);
  }

  Future<ActiveTrackSaveResult> _reconcileConflict(
    ActiveTrackRecord pending,
    Failure failure,
  ) async {
    final Result<UserProfile> result = await ref.read(userRepositoryProvider).getMe();
    if (result case Success<UserProfile>(:final UserProfile value)
        when value.id == pending.ownerId) {
      final String? remote = _normalizeTrackId(value.activeTrackId);
      final ActiveTrackStore store = ref.read(activeTrackStoreProvider);
      if (remote != null && pending.pendingPredecessors.contains(remote)) {
        final ActiveTrackRecord rebased = ActiveTrackRecord.pending(
          trackId: pending.trackId,
          ownerId: pending.ownerId,
          mutationId: pending.pendingMutationId!,
          baseTrackId: remote,
          predecessors: pending.pendingPredecessors
              .where((String trackId) => trackId != remote)
              .toList(growable: false),
        );
        try {
          await store.write(rebased);
        } on Object catch (error, stackTrace) {
          _report(error, stackTrace, 'while rebasing a pending certification');
          return const ActiveTrackSaveResult(
            ActiveTrackSaveStatus.rejected,
            CacheFailure('La certification en attente n’a pas pu être réconciliée.'),
          );
        }
        final Result<UserProfile> retry = await ref.read(userRepositoryProvider).setActiveTrack(
              trackId: rebased.trackId,
              expectedTrackId: remote,
            );
        return switch (retry) {
          Success<UserProfile>() => await _acceptSynced(rebased),
          Err<UserProfile>(failure: final Failure retryFailure) =>
            ActiveTrackSaveResult(ActiveTrackSaveStatus.rejected, retryFailure),
        };
      }
      try {
        if (remote == null) {
          await store.clear();
        } else {
          await store.write(
            ActiveTrackRecord.synced(trackId: remote, ownerId: pending.ownerId),
          );
        }
      } on Object catch (error, stackTrace) {
        _report(error, stackTrace, 'while persisting a reconciled certification');
        return const ActiveTrackSaveResult(
          ActiveTrackSaveStatus.rejected,
          CacheFailure('La certification en attente n’a pas pu être réconciliée.'),
        );
      }
      state = AsyncData<String?>(remote);
      ref.invalidate(meProvider);
      return ActiveTrackSaveResult(ActiveTrackSaveStatus.rejected, failure);
    }
    if (result case Success<UserProfile>()) {
      await _clearNow();
      return const ActiveTrackSaveResult(
        ActiveTrackSaveStatus.rejected,
        AuthFailure('Le compte actif a changé. Recommence la sélection.'),
      );
    }
    final Failure readFailure = (result as Err<UserProfile>).failure;
    return ActiveTrackSaveResult(ActiveTrackSaveStatus.rejected, readFailure);
  }

  Future<ActiveTrackSaveResult> _restore(
    ActiveTrackRecord? previous,
    Failure failure,
  ) async {
    final String? owner = previous?.ownerId ?? _ownerId;
    final String? currentOwner = _normalizeOwnerId(ref.read(activeTrackOwnerIdProvider));
    if (currentOwner != null && owner != null && currentOwner != owner) {
      await _clearNow();
      return const ActiveTrackSaveResult(
        ActiveTrackSaveStatus.rejected,
        AuthFailure('Le compte actif a changé. Recommence la sélection.'),
      );
    }
    try {
      final ActiveTrackStore store = ref.read(activeTrackStoreProvider);
      if (previous == null) {
        await store.clear();
      } else {
        await store.write(previous);
      }
      state = AsyncData<String?>(previous?.trackId);
    } on Object catch (error, stackTrace) {
      state = AsyncError<String?>(error, stackTrace);
      _report(error, stackTrace, 'while restoring the previous certification');
      return const ActiveTrackSaveResult(
        ActiveTrackSaveStatus.rejected,
        CacheFailure('Impossible de restaurer la certification précédente.'),
      );
    }
    return ActiveTrackSaveResult(ActiveTrackSaveStatus.rejected, failure);
  }

  Future<void> _restoreBase(ActiveTrackRecord pending, Failure failure) async {
    final ActiveTrackRecord? base = pending.pendingBaseTrackId == null
        ? null
        : ActiveTrackRecord.synced(
            trackId: pending.pendingBaseTrackId!,
            ownerId: pending.ownerId,
          );
    await _restore(base, failure);
  }

  Future<void> clear() async {
    _clearRequested = true;
    try {
      await _clearNow();
      final Future<void>? running = _mutationDone?.future;
      if (running != null) await running;
      await _clearNow();
    } finally {
      _clearRequested = false;
    }
  }

  Future<void> _clearNow() async {
    _selectionRevision++;
    try {
      await ref.read(activeTrackStoreProvider).clear();
      _ownerId = null;
      state = const AsyncData<String?>(null);
    } on Object catch (error, stackTrace) {
      state = AsyncError<String?>(error, stackTrace);
      _report(error, stackTrace, 'while clearing the certification after sign-out');
    }
  }

  void _report(Object error, StackTrace stackTrace, String operation) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'certigo.active-track',
        context: ErrorDescription(operation),
      ),
    );
  }

  void _beginMutation() {
    _mutating = true;
    _mutationDone = Completer<void>();
  }

  void _endMutation() {
    _mutating = false;
    _mutationDone?.complete();
    _mutationDone = null;
  }
}

final activeTrackProvider = AsyncNotifierProvider<ActiveTrackController, String?>(
  ActiveTrackController.new,
);

String? _normalizeTrackId(String? value) {
  final String normalized = (value ?? '').trim().toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

String? _normalizeOwnerId(String? value) {
  final String normalized = (value ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}

/// The catalog of certification tracks the app offers, for the course picker.
/// Auto-disposed: it is only loaded while the picker sheet is open.
final catalogProvider = FutureProvider.autoDispose<List<TrackSummary>>((Ref ref) async {
  return _orThrow(await ref.watch(catalogRepositoryProvider).getCatalog());
});

/// The "next best action" coach for one track: a server-ranked shelf of what
/// the learner should do next. Auto-disposed and keyed by trackId so Home can
/// surface a coaching section without recomputing anything on-device.
final nextBestProvider = FutureProvider.autoDispose.family<NextBest, String>((
  Ref ref,
  String trackId,
) async {
  return _orThrow(await ref.watch(recommendationRepositoryProvider).getNextBest(trackId));
});

/// The learner's current weekly league standings.
final leagueProvider = FutureProvider.autoDispose<League>((Ref ref) async {
  return _orThrow(await ref.watch(leaderboardRepositoryProvider).getMyLeague());
});

/// The current monthly season: theme, mascot, gem balance and the claimable
/// challenge. Auto-disposed; refreshed after a claim via `ref.invalidate`.
final seasonProvider = FutureProvider.autoDispose<Season>((Ref ref) async {
  return _orThrow(await ref.watch(seasonRepositoryProvider).getSeason());
});

/// Today's daily quest board with progress and claimable rewards. Auto-disposed;
/// refreshed after a claim via `ref.invalidate`.
final questBoardProvider = FutureProvider.autoDispose<QuestBoard>((Ref ref) async {
  return _orThrow(await ref.watch(questRepositoryProvider).getQuests());
});

/// The learner's achievements with per-achievement progress. Read-only.
final achievementBoardProvider = FutureProvider.autoDispose<AchievementBoard>((Ref ref) async {
  return _orThrow(await ref.watch(achievementRepositoryProvider).getAchievements());
});

/// The gem shop catalog plus the learner's current gem balance. Auto-disposed;
/// refreshed after a purchase via `ref.invalidate`.
final shopCatalogProvider = FutureProvider.autoDispose<ShopCatalog>((Ref ref) async {
  return _orThrow(await ref.watch(shopRepositoryProvider).getShop());
});

/// The learner's friends list. Auto-disposed; refreshed after add/remove.
final friendListProvider = FutureProvider.autoDispose<FriendList>((Ref ref) async {
  return _orThrow(await ref.watch(friendRepositoryProvider).getFriends());
});

/// The friends-only weekly leaderboard, highlighting the learner. Auto-disposed.
final friendLeaderboardProvider = FutureProvider.autoDispose<FriendLeaderboard>((Ref ref) async {
  return _orThrow(await ref.watch(friendRepositoryProvider).getFriendLeaderboard());
});

/// The server-authoritative daily share payload for the current learner.
final dailyShareCardProvider = FutureProvider.autoDispose<ShareCard>((Ref ref) async {
  return _orThrow(await ref.watch(shareCardRepositoryProvider).getDailyShareCard());
});

/// A freshly generated mock exam for the [activeTrackProvider] track: blueprint,
/// items and time limit. Auto-disposed so leaving the exam screen discards it;
/// switching the active track regenerates a new exam.
final examProvider = FutureProvider.autoDispose<MockExam>((Ref ref) async {
  final String? trackId = await ref.watch(activeTrackProvider.future);
  if (trackId == null) throw const MissingActiveTrackException();
  return _orThrow(
    await ref.watch(examRepositoryProvider).generateExam(MockExamRequest(trackId: trackId)),
  );
});
