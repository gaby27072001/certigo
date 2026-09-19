import 'package:certigo/shared/widgets/async_module.dart';
import 'package:certigo/shared/widgets/inline_error.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/error_message.dart';
import 'support/technical_shape.dart';

void main() {
  Future<void> pumpModule(
    WidgetTester tester,
    AsyncValue<String> state, {
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(
          body: AsyncModule<String>(
            state: state,
            onRetry: onRetry,
            loading: (BuildContext context) => const Text('Chargement'),
            data: (BuildContext context, String value) => Text(value),
          ),
        ),
      ),
    );
  }

  for (final probe in technicalCorpus) {
    testWidgets('default cold copy ignores ${probe.label} and retains retry', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await pumpModule(
        tester,
        AsyncError<String>(ServerFailure(probe.sample), StackTrace.current),
        onRetry: () => retries++,
      );

      expectNoTechnicalText(tester, context: 'AsyncModule / cold / ${probe.label}');
      expect(
        find.descendant(
          of: find.byType(PrismStatusView),
          matching: find.text('Vérifie ta connexion puis réessaie.'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Réessayer'));
      expect(retries, 1);
    });

    testWidgets('default stale copy ignores ${probe.label} without hiding the failure', (
      WidgetTester tester,
    ) async {
      await pumpModule(
        tester,
        AsyncError<String>(ServerFailure(probe.sample), StackTrace.current)
            .copyWithPrevious(const AsyncData<String>('Contenu déjà chargé')),
      );

      expectNoTechnicalText(tester, context: 'AsyncModule / stale / ${probe.label}');
      expect(AsyncModule.defaultStaleMessage.trim(), isNotEmpty);
      expect(
        find.descendant(
          of: find.byType(InlineError),
          matching: find.text(AsyncModule.defaultStaleMessage),
        ),
        findsOneWidget,
      );
      expect(find.text('Contenu déjà chargé'), findsOneWidget);
      expect(find.byType(PrismStatusView), findsNothing);
    });
  }
}
