enum AccountDeletionPhase { notRequested, pending, completed }

class AccountDeletion {
  const AccountDeletion({
    required this.status,
    required this.completedSteps,
    required this.totalSteps,
    this.requestedAt,
    this.completedAt,
    this.failureCode,
    this.retryAfterSeconds,
  });

  final AccountDeletionPhase status;
  final int completedSteps;
  final int totalSteps;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final String? failureCode;
  final int? retryAfterSeconds;

  bool get isPending => status == AccountDeletionPhase.pending;
  bool get isCompleted => status == AccountDeletionPhase.completed;

  double get progress {
    if (totalSteps <= 0) return 0;
    return (completedSteps / totalSteps).clamp(0, 1).toDouble();
  }

  factory AccountDeletion.fromJson(Map<String, dynamic> json) {
    final String? rawStatus = json['status'] as String?;
    return AccountDeletion(
      status: switch (rawStatus) {
        'pending' => AccountDeletionPhase.pending,
        'completed' => AccountDeletionPhase.completed,
        _ => AccountDeletionPhase.notRequested,
      },
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      requestedAt: _date(json['requestedAt']),
      completedAt: _date(json['completedAt']),
      failureCode: json['failureCode'] as String?,
      retryAfterSeconds: (json['retryAfterSeconds'] as num?)?.toInt(),
    );
  }

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
}
