import 'package:data/data.dart';

/// Lifecycle of one tutor consultation for a single answered item.
enum TutorStatus { idle, loading, ready, error }

/// Immutable snapshot of a tutor request/response cycle. The controller swaps
/// whole instances; the sheet is a pure function of this state.
class TutorState {
  const TutorState({this.status = TutorStatus.idle, this.explanation, this.errorMessage});

  final TutorStatus status;
  final TutorExplanation? explanation;
  final String? errorMessage;

  bool get isLoading => status == TutorStatus.loading;
  bool get hasExplanation => status == TutorStatus.ready && explanation != null;
  bool get hasError => status == TutorStatus.error;

  TutorState copyWith({TutorStatus? status, TutorExplanation? explanation, String? errorMessage}) {
    return TutorState(
      status: status ?? this.status,
      explanation: explanation ?? this.explanation,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
