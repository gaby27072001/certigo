/// Durable offline action queue — value types.
///
/// A [SyncAction] is one mutating API call (e.g. a quiz submission) captured
/// because the device was offline or the request failed transiently. It is
/// persisted verbatim and replayed when connectivity returns.
///
/// Replay is safe by construction: every action carries an [idempotencyKey]
/// that the server uses to dedupe. A replayed action returns the original
/// authoritative result and never double-counts XP, gems or streak.
library;

/// Lifecycle of a queued action.
enum SyncActionStatus {
  /// Awaiting (or backing off before) dispatch.
  pending,

  /// Dispatched successfully; kept briefly so a restart can still dedupe it.
  done,

  /// Permanently failed (non-retryable, or retries exhausted). Kept for
  /// diagnostics; never dispatched again.
  dead,
}

SyncActionStatus _statusFromWire(String? value) => switch (value) {
      'done' => SyncActionStatus.done,
      'dead' => SyncActionStatus.dead,
      _ => SyncActionStatus.pending,
    };

String _statusToWire(SyncActionStatus status) => switch (status) {
      SyncActionStatus.pending => 'pending',
      SyncActionStatus.done => 'done',
      SyncActionStatus.dead => 'dead',
    };

/// An immutable, durably-persisted unit of offline work.
class SyncAction {
  const SyncAction({
    required this.id,
    required this.kind,
    required this.endpoint,
    required this.payload,
    required this.idempotencyKey,
    required this.createdAt,
    this.ownerId,
    this.publicManifestId,
    this.status = SyncActionStatus.pending,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.completedAt,
  });

  /// Unique id for this queue entry (distinct from [idempotencyKey]).
  final String id;

  /// Logical action type, e.g. `quizSubmit`. Drives routing and telemetry.
  final String kind;

  /// REST path to POST, e.g. `/quiz/{lessonId}/submit`.
  final String endpoint;

  /// JSON body to send. Must be self-contained (no in-memory references) so it
  /// survives serialization across app restarts.
  final Map<String, dynamic> payload;

  /// Server-side dedup key (e.g. the quiz `clientAttemptId`). Two actions with
  /// the same key are the *same* intent and must never both take effect.
  final String idempotencyKey;

  /// When the action was first enqueued.
  final DateTime createdAt;

  /// Authenticated account that created this action. Null only for legacy v1
  /// records, which the engine quarantines instead of replaying under a new user.
  final String? ownerId;

  /// Public content revision used to create the action. Null only for legacy
  /// actions created before runtime manifest pinning.
  final String? publicManifestId;

  final SyncActionStatus status;

  /// Number of dispatch attempts made so far.
  final int attempts;

  /// Earliest time the next attempt may run (backoff gate). Null = immediately.
  final DateTime? nextAttemptAt;

  /// Last failure category/message, for diagnostics.
  final String? lastError;

  /// When the action reached [SyncActionStatus.done].
  final DateTime? completedAt;

  bool get isPending => status == SyncActionStatus.pending;
  bool get isDone => status == SyncActionStatus.done;
  bool get isDead => status == SyncActionStatus.dead;

  /// Whether this pending action is due to run at [now] (backoff elapsed).
  bool isDue(DateTime now) {
    if (!isPending) return false;
    final DateTime? gate = nextAttemptAt;
    return gate == null || !now.isBefore(gate);
  }

  SyncAction copyWith({
    SyncActionStatus? status,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    String? lastError,
    bool clearLastError = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return SyncAction(
      id: id,
      kind: kind,
      endpoint: endpoint,
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      ownerId: ownerId,
      publicManifestId: publicManifestId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: clearNextAttemptAt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind,
        'endpoint': endpoint,
        'payload': payload,
        'idempotencyKey': idempotencyKey,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (ownerId != null) 'ownerId': ownerId,
        if (publicManifestId != null) 'publicManifestId': publicManifestId,
        'status': _statusToWire(status),
        'attempts': attempts,
        if (nextAttemptAt != null) 'nextAttemptAt': nextAttemptAt!.toUtc().toIso8601String(),
        if (lastError != null) 'lastError': lastError,
        if (completedAt != null) 'completedAt': completedAt!.toUtc().toIso8601String(),
      };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
        id: json['id'] as String,
        kind: json['kind'] as String,
        endpoint: json['endpoint'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map<dynamic, dynamic>),
        idempotencyKey: json['idempotencyKey'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ownerId: json['ownerId'] as String?,
        publicManifestId: json['publicManifestId'] as String?,
        status: _statusFromWire(json['status'] as String?),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        nextAttemptAt:
            json['nextAttemptAt'] == null ? null : DateTime.parse(json['nextAttemptAt'] as String),
        lastError: json['lastError'] as String?,
        completedAt:
            json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
      );
}
