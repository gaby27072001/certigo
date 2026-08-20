import 'package:core/core.dart';
import 'package:data/data.dart';

UserProfile testUserProfile({String id = 'user-1', String? activeTrackId}) => UserProfile(
      id: id,
      displayName: 'Test Learner',
      handle: 'test-learner',
      avatarUrl: null,
      xp: 120,
      level: 2,
      streakDays: 3,
      freezeTokens: 1,
      gems: 20,
      dailyGoalXp: 50,
      dailyXpEarned: 10,
      activeTrackId: activeTrackId,
    );

class FakeUserRepository implements UserRepository {
  FakeUserRepository({
    UserProfile? profile,
    this.getFailure,
    this.setFailure,
    this.onSetActiveTrack,
  }) : profile = profile ?? testUserProfile();

  UserProfile profile;
  Failure? getFailure;
  Failure? setFailure;
  Future<Result<UserProfile>> Function(String trackId, String? expectedTrackId)? onSetActiveTrack;
  int getCalls = 0;
  final List<String> setActiveTrackCalls = <String>[];
  final List<String?> expectedTrackCalls = <String?>[];

  @override
  Future<Result<UserProfile>> getMe() async {
    getCalls++;
    final Failure? failure = getFailure;
    return failure == null ? Success<UserProfile>(profile) : Err<UserProfile>(failure);
  }

  @override
  Future<Result<UserProfile>> setActiveTrack({
    required String trackId,
    required String? expectedTrackId,
  }) async {
    setActiveTrackCalls.add(trackId);
    expectedTrackCalls.add(expectedTrackId);
    final Future<Result<UserProfile>> Function(String, String?)? callback = onSetActiveTrack;
    if (callback != null) return callback(trackId, expectedTrackId);
    final Failure? failure = setFailure;
    if (failure != null) return Err<UserProfile>(failure);
    if (profile.activeTrackId == trackId) return Success<UserProfile>(profile);
    if (profile.activeTrackId != expectedTrackId) {
      return const Err<UserProfile>(
        ServerFailure('Active track conflict', statusCode: 409),
      );
    }
    profile = UserProfile(
      id: profile.id,
      displayName: profile.displayName,
      handle: profile.handle,
      avatarUrl: profile.avatarUrl,
      xp: profile.xp,
      level: profile.level,
      streakDays: profile.streakDays,
      freezeTokens: profile.freezeTokens,
      gems: profile.gems,
      dailyGoalXp: profile.dailyGoalXp,
      dailyXpEarned: profile.dailyXpEarned,
      activeTrackId: trackId,
    );
    return Success<UserProfile>(profile);
  }
}
