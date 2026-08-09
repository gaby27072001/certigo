import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/router.dart';
import '../application/lesson_args.dart';
import '../application/lesson_controller.dart';
import '../application/lesson_session_state.dart';
import '../application/lesson_step.dart';
import 'widgets/lesson_dock.dart';
import 'widgets/lesson_progress_header.dart';
import 'widgets/result_feedback_widget.dart';
import 'widgets/step_renderer.dart';

/// Lesson player — a paginated state machine that walks the learner through the
/// "Learn Loop" (Hook → Concept → Example → Code → Check → Recap), grades inline
/// comprehension checks, submits the attempt, then shows a result.
///
/// All session logic lives in [LessonController]; this widget is a thin,
/// declarative shell over [LessonSessionState]. The public constructor is
/// unchanged so the router needs no edit.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.trackId, required this.lessonId});

  final String trackId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LessonArgs args = LessonArgs(trackId: trackId, lessonId: lessonId);
    final LessonSessionState state = ref.watch(lessonControllerProvider(args));
    final LessonController controller = ref.read(lessonControllerProvider(args).notifier);

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: switch (state.status) {
            LessonStatus.idle || LessonStatus.loading => const _LessonLoadingView(),
            LessonStatus.error => PrismStatusView.error(onRetry: controller.load),
            _ => _LessonRunningView(state: state, controller: controller),
          },
        ),
      ),
    );
  }
}

class _LessonRunningView extends StatelessWidget {
  const _LessonRunningView({required this.state, required this.controller});

  final LessonSessionState state;
  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final LessonStep? step = state.current;
    final bool isResult = step?.kind == LessonStepKind.result;
    final bool showResult = isResult && state.result != null;

    final Widget inner;
    final Key stepKey;
    if (showResult) {
      stepKey = const ValueKey<String>('result');
      inner = ResultFeedbackWidget(
        result: state.result!,
        lesson: state.lesson!,
        trackId: controller.args.trackId,
        lessonId: controller.args.lessonId,
        answers: state.answers,
        onContinue: () => context.go(Routes.home),
        onReview: () => context.go(Routes.path),
      );
    } else if (isResult) {
      // Result step reached but the attempt isn't back yet.
      stepKey = const ValueKey<String>('submitting');
      inner = const _LessonLoadingView();
    } else {
      stepKey = ValueKey<int>(state.index);
      inner = StepRenderer(
        state: state,
        onToggleOption: controller.toggleOption,
        onToggleMatch: controller.toggleMatch,
      );
    }

    // Each step is an opaque page: the incoming step fully covers the outgoing
    // one during the transition, so two questions can never superimpose.
    final Widget body = _OpaqueStep(key: stepKey, child: inner);

    return Column(
      children: <Widget>[
        LessonProgressHeader(
          progress: state.progress,
          minutes: state.lesson?.estMinutes ?? 0,
          onClose: () => context.go(Routes.path),
        ),
        Expanded(child: PrismStepSwitcher(child: body)),
        if (!isResult)
          LessonDock(
            state: state,
            onValidate: controller.submitCheck,
            onAdvance: controller.advance,
          ),
      ],
    );
  }
}

/// Wraps a lesson step in a solid background so transitions never bleed through.
class _OpaqueStep extends StatelessWidget {
  const _OpaqueStep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.prism.background, child: child);
  }
}

class _LessonLoadingView extends StatelessWidget {
  const _LessonLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.screen,
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        SizedBox(height: 12),
        PrismSkeleton(width: 120, height: 26),
        SizedBox(height: 22),
        PrismSkeleton(height: 18),
        SizedBox(height: 10),
        PrismSkeleton(height: 18),
        SizedBox(height: 10),
        PrismSkeleton(width: 220, height: 18),
        SizedBox(height: 28),
        PrismSkeleton(height: 120),
      ],
    );
  }
}
