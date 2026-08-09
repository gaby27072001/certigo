/// Friends / social graph. The learner's friends list, add-by-handle, remove,
/// and a friends-only leaderboard. The friends leaderboard reuses the shared
/// [LeaderboardEntry] row model.
library;

import 'leaderboard.dart' show LeaderboardEntry;

/// One friend in the learner's social graph.
class Friend {
  const Friend({
    required this.userId,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    required this.level,
    required this.streakDays,
    required this.xp,
    required this.friendsSince,
  });

  final String userId;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final int level;
  final int streakDays;
  final int xp;
  final DateTime friendsSince;

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? 'Apprenant',
        handle: json['handle'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        level: (json['level'] as num?)?.toInt() ?? 1,
        streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        friendsSince: DateTime.parse(
          json['friendsSince'] as String? ?? DateTime.now().toUtc().toIso8601String(),
        ),
      );
}

/// The learner's friends list with a convenience [count].
class FriendList {
  const FriendList({required this.count, required this.friends});

  final int count;
  final List<Friend> friends;

  factory FriendList.fromJson(Map<String, dynamic> json) => FriendList(
        count: (json['count'] as num?)?.toInt() ?? 0,
        friends: (json['friends'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Friend.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Request body for `POST /friends` (add by handle).
class AddFriendRequest {
  const AddFriendRequest({required this.handle});

  final String handle;

  Map<String, dynamic> toJson() => <String, dynamic>{'handle': handle};
}

/// Server result of an add/remove friend action — carries the refreshed list so
/// the UI can update from a single round-trip.
class FriendActionResult {
  const FriendActionResult({
    required this.success,
    this.friendUserId,
    this.error,
    required this.friends,
  });

  final bool success;
  final String? friendUserId;
  final String? error;
  final FriendList friends;

  factory FriendActionResult.fromJson(Map<String, dynamic> json) => FriendActionResult(
        success: json['success'] as bool? ?? false,
        friendUserId: json['friendUserId'] as String?,
        error: json['error'] as String?,
        friends:
            FriendList.fromJson(json['friends'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      );
}

/// The friends-only weekly leaderboard, highlighting the learner via [meUserId].
class FriendLeaderboard {
  const FriendLeaderboard({required this.meUserId, required this.entries});

  final String meUserId;
  final List<LeaderboardEntry> entries;

  factory FriendLeaderboard.fromJson(Map<String, dynamic> json) => FriendLeaderboard(
        meUserId: json['meUserId'] as String? ?? '',
        entries: (json['entries'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
