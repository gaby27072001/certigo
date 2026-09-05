import 'package:core/core.dart';
import '../api/api_client.dart';
import '../models/user_profile.dart';
import '../models/learning_path.dart';
import '../models/track_summary.dart';
import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/leaderboard.dart';
import '../models/tutor.dart';
import '../models/recommendation.dart';
import '../models/season.dart';
import '../models/quest.dart';
import '../models/achievement.dart';
import '../models/shop.dart';
import '../models/friend.dart';
import '../models/exam.dart';
import '../models/share_card.dart';
import '../models/account_deletion.dart';
import 'repositories.dart';

/// HTTP-backed implementations of the repository contracts. Each method maps a
/// single REST endpoint to a typed model via [ApiClient]. Routes mirror the
/// backend exactly (userId is always derived from the JWT, never sent).

const String _kAppCatalogSchema = 'certigo.app-certification-catalog/v2';
const String _kCanonicalCatalogSchema = 'certigo.certification-catalog/v1';

List<TrackSummary> _decodeTrackSummaries(Map<String, dynamic> json) {
  final String? schema = json['schema'] as String?;
  final String? sourceSchema = json['sourceSchema'] as String?;
  if (schema != _kAppCatalogSchema) {
    throw FormatException('Unsupported app catalog schema: $schema');
  }
  if (sourceSchema != _kCanonicalCatalogSchema) {
    throw FormatException('Unsupported source catalog schema: $sourceSchema');
  }
  final List<dynamic> tracks = json['tracks'] as List<dynamic>? ?? <dynamic>[];
  return tracks.map((dynamic e) => TrackSummary.fromJson(e as Map<String, dynamic>)).toList();
}

class RemoteUserRepository implements UserRepository {
  const RemoteUserRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<UserProfile>> getMe() => _api.getJson('/me', UserProfile.fromJson);

  @override
  Future<Result<UserProfile>> setActiveTrack({
    required String trackId,
    required String? expectedTrackId,
  }) =>
      _api.postJson(
          '/me/active-track',
          <String, dynamic>{
            'trackId': trackId,
            'expectedTrackId': expectedTrackId,
          },
          UserProfile.fromJson);
}

class RemoteAccountDeletionRepository implements AccountDeletionRepository {
  const RemoteAccountDeletionRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<AccountDeletion>> getStatus() =>
      _api.getJson('/account/deletion', AccountDeletion.fromJson);

  @override
  Future<Result<AccountDeletion>> requestDeletion({String? reauthenticationToken}) => _api.postJson(
        '/account/deletion',
        const <String, dynamic>{},
        AccountDeletion.fromJson,
        headers: reauthenticationToken == null
            ? null
            : <String, dynamic>{'X-Certigo-Reauthentication': reauthenticationToken},
      );
}

class RemotePathRepository implements PathRepository {
  const RemotePathRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<LearningPath>> getPath(String trackId) =>
      _api.getJson('/me/paths/${Uri.encodeComponent(trackId)}', LearningPath.fromJson);
}

class RemoteCatalogRepository implements CatalogRepository {
  const RemoteCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<TrackSummary>>> getCatalog() async {
    final Result<List<TrackSummary>> result = await _api.getJson(
      '/catalog/tracks',
      _decodeTrackSummaries,
    );
    return result.when(
      success: (tracks) => tracks.isEmpty
          ? const Err(
              CatalogEmptyFailure(
                'Aucune certification disponible — le catalogue n\'a pas encore été alimenté.',
              ),
            )
          : Success(tracks),
      failure: Err.new,
    );
  }
}

class RemoteLessonRepository implements LessonRepository {
  const RemoteLessonRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<Lesson>> getLesson({required String trackId, required String lessonId}) =>
      _api.getJsonWithHeaders(
        '/tracks/${Uri.encodeComponent(trackId)}/lessons/${Uri.encodeComponent(lessonId)}',
        (Map<String, dynamic> json, headers) =>
            Lesson.fromJson(json).withPublicManifestId(headers.value('x-content-manifest-id')),
      );
}

class RemoteQuizRepository implements QuizRepository {
  const RemoteQuizRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) =>
      _api.postJson('/quiz/$lessonId/submit', request.toJson(), SubmitQuizResult.fromJson);
}

class RemoteLeaderboardRepository implements LeaderboardRepository {
  const RemoteLeaderboardRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<League>> getMyLeague() => _api.getJson('/me/league', League.fromJson);
}

class RemoteTutorRepository implements TutorRepository {
  const RemoteTutorRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<TutorExplanation>> explain(TutorExplainRequest request) =>
      _api.postJson('/tutor/explain', request.toJson(), TutorExplanation.fromJson);
}

class RemoteRecommendationRepository implements RecommendationRepository {
  const RemoteRecommendationRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<NextBest>> getNextBest(String trackId) =>
      _api.getJson('/me/recommendations/${Uri.encodeComponent(trackId)}', NextBest.fromJson);
}

class RemoteSeasonRepository implements SeasonRepository {
  const RemoteSeasonRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<Season>> getSeason() => _api.getJson('/season', Season.fromJson);

  @override
  Future<Result<ClaimSeasonResult>> claimSeason(ClaimSeasonRequest request) =>
      _api.postJson('/season/claim', request.toJson(), ClaimSeasonResult.fromJson);
}

class RemoteQuestRepository implements QuestRepository {
  const RemoteQuestRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<QuestBoard>> getQuests() => _api.getJson('/quests', QuestBoard.fromJson);

  @override
  Future<Result<ClaimQuestResult>> claimQuest(ClaimQuestRequest request) =>
      _api.postJson('/quests/claim', request.toJson(), ClaimQuestResult.fromJson);
}

class RemoteAchievementRepository implements AchievementRepository {
  const RemoteAchievementRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<AchievementBoard>> getAchievements() =>
      _api.getJson('/achievements', AchievementBoard.fromJson);
}

class RemoteShopRepository implements ShopRepository {
  const RemoteShopRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<ShopCatalog>> getShop() => _api.getJson('/shop', ShopCatalog.fromJson);

  @override
  Future<Result<PurchaseResult>> purchase(PurchaseRequest request) =>
      _api.postJson('/shop/purchase', request.toJson(), PurchaseResult.fromJson);
}

class RemoteFriendRepository implements FriendRepository {
  const RemoteFriendRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<FriendList>> getFriends() => _api.getJson('/friends', FriendList.fromJson);

  @override
  Future<Result<FriendActionResult>> addFriend(AddFriendRequest request) =>
      _api.postJson('/friends', request.toJson(), FriendActionResult.fromJson);

  @override
  Future<Result<FriendActionResult>> removeFriend(String friendId) =>
      _api.deleteJson('/friends/$friendId', FriendActionResult.fromJson);

  @override
  Future<Result<FriendLeaderboard>> getFriendLeaderboard() =>
      _api.getJson('/friends/leaderboard', FriendLeaderboard.fromJson);
}

class RemoteShareCardRepository implements ShareCardRepository {
  const RemoteShareCardRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<ShareCard>> getDailyShareCard() => _api.getJson('/share/daily', ShareCard.fromJson);
}

class RemoteExamRepository implements ExamRepository {
  const RemoteExamRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<MockExam>> generateExam(MockExamRequest request) =>
      _api.postJson('/exam/generate', request.toJson(), MockExam.fromJson);

  @override
  Future<Result<MockExamResult>> submitExam(SubmitMockExamRequest request) =>
      _api.postJson('/exam/submit', request.toJson(), MockExamResult.fromJson);
}
