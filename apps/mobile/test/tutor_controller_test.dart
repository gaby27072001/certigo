import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microlingo/app/providers.dart';
import 'package:microlingo/features/tutor/application/tutor_controller.dart';
import 'package:microlingo/features/tutor/application/tutor_state.dart';

/// A tutor repository that returns a canned [Result] and records the request it
/// was asked to explain, so we can assert the controller forwards it verbatim.
class _FakeTutorRepo implements TutorRepository {
  _FakeTutorRepo(this._result);

  final Result<TutorExplanation> _result;
  TutorExplainRequest? lastRequest;
  int calls = 0;

  @override
  Future<Result<TutorExplanation>> explain(TutorExplainRequest request) async {
    calls++;
    lastRequest = request;
    return _result;
  }
}

const TutorExplainRequest _req = TutorExplainRequest(
  trackId: 'az-900',
  lessonId: 'shared-responsibility-1',
  itemId: 'chk-shared-1',
  selected: <String>['b'],
);

const TutorExplanation _explanation = TutorExplanation(
  itemId: 'chk-shared-1',
  conceptId: 'shared-responsibility',
  correct: false,
  headline: 'On reprend la responsabilité partagée ensemble.',
  points: <String>['Le client garde la maîtrise de ses données.'],
  encouragement: 'Tu progresses, ça rentre.',
  recommendation: 'Refais la leçon « Responsabilité partagée ».',
  citedConceptIds: <String>['shared-responsibility'],
  source: 'grounded',
  personalization: TutorPersonalization(
    attempts: 2,
    errors: 1,
    accuracyPct: 50,
    recurringStruggle: false,
    masteredBefore: false,
    trend: 'steady',
  ),
);

void main() {
  group('TutorController', () {
    ProviderContainer containerWith(TutorRepository repo) {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[tutorRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      // Keep the auto-disposed family alive for the duration of the test.
      container.listen<TutorState>(
        tutorControllerProvider(_req.itemId),
        (TutorState? _, TutorState __) {},
      );
      return container;
    }

    test('starts idle before any consultation', () {
      final ProviderContainer container = containerWith(
        _FakeTutorRepo(const Success<TutorExplanation>(_explanation)),
      );
      expect(container.read(tutorControllerProvider(_req.itemId)).status, TutorStatus.idle);
    });

    test('goes loading then ready and forwards the request unchanged', () async {
      final _FakeTutorRepo repo = _FakeTutorRepo(const Success<TutorExplanation>(_explanation));
      final ProviderContainer container = containerWith(repo);
      final TutorController controller =
          container.read(tutorControllerProvider(_req.itemId).notifier);

      final Future<void> pending = controller.explain(_req);
      expect(container.read(tutorControllerProvider(_req.itemId)).status, TutorStatus.loading);

      await pending;

      final TutorState state = container.read(tutorControllerProvider(_req.itemId));
      expect(state.status, TutorStatus.ready);
      expect(state.hasExplanation, isTrue);
      expect(state.explanation?.headline, _explanation.headline);
      expect(repo.lastRequest, same(_req));
      expect(repo.calls, 1);
    });

    test('surfaces the failure message on error', () async {
      final ProviderContainer container = containerWith(
        _FakeTutorRepo(const Err<TutorExplanation>(NetworkFailure())),
      );
      final TutorController controller =
          container.read(tutorControllerProvider(_req.itemId).notifier);

      await controller.explain(_req);

      final TutorState state = container.read(tutorControllerProvider(_req.itemId));
      expect(state.status, TutorStatus.error);
      expect(state.hasError, isTrue);
      expect(state.errorMessage, isNotNull);
      expect(state.explanation, isNull);
    });

    test('ignores a second call while a request is already in flight', () async {
      final _FakeTutorRepo repo = _FakeTutorRepo(const Success<TutorExplanation>(_explanation));
      final ProviderContainer container = containerWith(repo);
      final TutorController controller =
          container.read(tutorControllerProvider(_req.itemId).notifier);

      final Future<void> first = controller.explain(_req);
      // Second call lands while the first is mid-flight → must be dropped.
      final Future<void> second = controller.explain(_req);
      await Future.wait(<Future<void>>[first, second]);

      expect(repo.calls, 1);
    });
  });
}
