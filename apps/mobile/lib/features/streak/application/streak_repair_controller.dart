import 'dart:math';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// Where one repair request stands on the « Ma série » screen.
enum StreakRepairPhase {
  /// Nothing asked yet.
  idle,

  /// The request is in flight.
  repairing,

  /// The server granted the repair.
  granted,

  /// The server refused it: a ruling, with its cause.
  refused,

  /// No ruling reached the app. The outcome is unknown, so the idempotency key
  /// is kept for the retry.
  failed,
}

@immutable
class StreakRepairState {
  const StreakRepairState._(this.phase, {this.result, this.failure});

  const StreakRepairState.idle() : this._(StreakRepairPhase.idle);

  const StreakRepairState.repairing() : this._(StreakRepairPhase.repairing);

  factory StreakRepairState.ruled(StreakRepairResult result) => StreakRepairState._(
        result.success ? StreakRepairPhase.granted : StreakRepairPhase.refused,
        result: result,
      );

  factory StreakRepairState.failed(Failure failure) =>
      StreakRepairState._(StreakRepairPhase.failed, failure: failure);

  final StreakRepairPhase phase;

  /// The server's ruling, when [phase] is granted or refused.
  final StreakRepairResult? result;

  /// Why no ruling arrived, when [phase] is failed.
  final Failure? failure;

  bool get repairing => phase == StreakRepairPhase.repairing;
}

/// Mints the idempotency key of one repair.
typedef ClientRepairIdGenerator = String Function();

/// A seam so tests can pin the keys a repair sends.
final clientRepairIdGeneratorProvider = Provider<ClientRepairIdGenerator>(
  (Ref ref) => newClientRepairId,
);

/// Same shape as the quiz and shop keys: unique per learner, not a secret.
String newClientRepairId() {
  final int micros = DateTime.now().microsecondsSinceEpoch;
  final int rand = Random.secure().nextInt(0x7fffffff);
  return '${micros.toRadixString(16)}-${rand.toRadixString(16)}';
}

final streakRepairControllerProvider =
    NotifierProvider.autoDispose<StreakRepairController, StreakRepairState>(
  StreakRepairController.new,
);

/// Sends a repair and keeps its idempotency key for exactly as long as its
/// outcome is unknown.
///
/// The server dedupes a repair on `clientRepairId`, so a retry after a transport
/// failure — where the debit may already have been applied — must replay the
/// *same* key to resolve to that same operation. Once the server has ruled,
/// granted or refused, the key is spent and the next repair mints a new one.
///
/// Losing the key with the screen is safe, which is why this controller may be
/// auto-disposed: a granted repair moves the last active day to yesterday, and
/// the server refuses any later request for the same gap (`intact`, or
/// `noLongerRepairable` for one already in flight). A new key therefore never
/// charges twice for one break; the held key only makes the retry report the
/// original success instead of that refusal.
class StreakRepairController extends AutoDisposeNotifier<StreakRepairState> {
  String? _pendingRepairId;

  @override
  StreakRepairState build() => const StreakRepairState.idle();

  Future<void> repair() async {
    if (state.repairing) return;
    state = const StreakRepairState.repairing();
    final String clientRepairId = _pendingRepairId ??= ref.read(clientRepairIdGeneratorProvider)();

    // Stay alive until the ruling lands, even if the learner leaves the screen:
    // the ruling must refresh every surface showing the streak or the gems, and
    // it must do so through a ref that is still mounted.
    final KeepAliveLink keepAlive = ref.keepAlive();
    try {
      final Result<StreakRepairResult> outcome = await ref
          .read(streakRepositoryProvider)
          .repair(StreakRepairRequest(clientRepairId: clientRepairId));
      outcome.when(
        success: (StreakRepairResult result) {
          _pendingRepairId = null;
          state = StreakRepairState.ruled(result);
          ref.invalidate(streakStatusProvider);
          if (result.success) {
            ref.invalidate(meProvider);
          }
        },
        failure: (Failure failure) {
          state = StreakRepairState.failed(failure);
        },
      );
    } finally {
      keepAlive.close();
    }
  }
}
