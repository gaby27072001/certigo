import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Thin abstraction over the platform share sheet so widget tests can verify
/// the daily-share flow without talking to platform channels.
abstract interface class ShareIntent {
  Future<void> shareText(String text, {String? subject});
}

class SharePlusIntent implements ShareIntent {
  const SharePlusIntent();

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}

final shareIntentProvider = Provider<ShareIntent>(
  (Ref ref) => const SharePlusIntent(),
);
