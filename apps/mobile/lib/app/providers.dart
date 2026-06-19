import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data/data.dart';

/// Root dependency wiring for the app, expressed as Riverpod providers.
///
/// This is the composition layer: it constructs the [ApiClient] and the
/// concrete repositories, then exposes them as abstractions so feature
/// controllers depend only on interfaces. Swapping a repo for a fake in tests
/// is a one-line `overrideWithValue`.

/// Supplies the current access token to the API client.
///
/// Wired to a no-op in the skeleton; the auth feature (Entra External ID) will
/// override this with a real token source via `ProviderScope.overrides`.
final tokenProvider = Provider<TokenProvider>((Ref ref) {
  return () async => null;
});

final apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(tokenProvider: ref.watch(tokenProvider));
});

final userRepositoryProvider = Provider<UserRepository>(
  (Ref ref) => RemoteUserRepository(ref.watch(apiClientProvider)),
);

final pathRepositoryProvider = Provider<PathRepository>(
  (Ref ref) => RemotePathRepository(ref.watch(apiClientProvider)),
);

final lessonRepositoryProvider = Provider<LessonRepository>(
  (Ref ref) => RemoteLessonRepository(ref.watch(apiClientProvider)),
);

final quizRepositoryProvider = Provider<QuizRepository>(
  (Ref ref) => RemoteQuizRepository(ref.watch(apiClientProvider)),
);

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (Ref ref) => RemoteLeaderboardRepository(ref.watch(apiClientProvider)),
);

/// User-controlled theme mode (persisted by settings later). System by default.
final themeModeProvider = StateProvider<ThemeMode>((Ref ref) => ThemeMode.system);
