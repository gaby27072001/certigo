import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'tutor_state.dart';

/// Drives one tutor consultation: ask the continuously-learning agent to explain
/// a single answered item, then expose loading / ready / error for the sheet.
///
/// The tutor is grounded server-side (the client never sees an answer key here)
/// and the backend folds each call into the learner's running model, so every
/// consultation also sharpens the next explanation for this learner.
class TutorController extends StateNotifier<TutorState> {
  TutorController(this._tutor) : super(const TutorState());

  final TutorRepository _tutor;

  /// Fetch a grounded, personalised explanation. Safe to trigger once per sheet;
  /// a second call while a request is already in flight is ignored.
  Future<void> explain(TutorExplainRequest request) async {
    if (state.status == TutorStatus.loading) return;
    state = state.copyWith(status: TutorStatus.loading);

    final Result<TutorExplanation> res = await _tutor.explain(request);
    if (!mounted) return;

    state = res.when(
      success: (TutorExplanation e) => TutorState(status: TutorStatus.ready, explanation: e),
      failure: (Failure f) => TutorState(status: TutorStatus.error, errorMessage: f.message),
    );
  }
}

/// One tutor controller per answered item, auto-disposed when its sheet closes
/// so each consultation starts fresh (and re-reads the latest personalisation).
final tutorControllerProvider = StateNotifierProvider.autoDispose
    .family<TutorController, TutorState, String>(
      (Ref ref, String itemId) => TutorController(ref.watch(tutorRepositoryProvider)),
    );
