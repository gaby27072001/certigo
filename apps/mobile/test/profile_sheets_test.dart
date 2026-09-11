import 'package:certigo/features/profile/presentation/widgets/profile_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// The Profile carried the app's densest cluster of raw Material: five
/// `AlertDialog`s built from `RadioListTile`, `CheckboxListTile`, `ListTile`
/// and bare `TextButton` actions. These tests pin the replacement — the sheets
/// select through [ChoiceTile], the component whose selected state is already
/// correct everywhere else, and no stock Material picker comes back.
void main() {
  Future<void> open(WidgetTester tester, Future<void> Function(BuildContext c) run) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext c) => Center(
              child: ElevatedButton(onPressed: () => run(c), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void expectNoStockPicker() {
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(RadioListTile<Object>), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  }

  group('single choice', () {
    testWidgets('selects through ChoiceTile and returns the picked value', (
      WidgetTester tester,
    ) async {
      int? result;
      await open(tester, (BuildContext c) async {
        result = await showProfileChoiceSheet<int>(
          context: c,
          title: 'Objectif quotidien',
          selected: 1,
          options: const <ProfileOption<int>>[
            ProfileOption<int>(value: 0, label: 'Tranquille', trailing: '3 min / j'),
            ProfileOption<int>(value: 1, label: 'Sérieux', trailing: '10 min / j'),
            ProfileOption<int>(value: 2, label: 'Intensif', trailing: '15 min / j'),
          ],
        );
      });

      expect(find.text('Objectif quotidien'), findsOneWidget);
      expect(find.byType(ChoiceTile), findsNWidgets(3));
      expectNoStockPicker();

      await tester.tap(find.text('Intensif'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ProfileSheetLabels.save));
      await tester.pumpAndSettle();

      expect(result, 2);
    });

    testWidgets('cancelling returns nothing, so the preference is untouched', (
      WidgetTester tester,
    ) async {
      int? result = -1;
      await open(tester, (BuildContext c) async {
        result = await showProfileChoiceSheet<int>(
          context: c,
          title: 'Niveau',
          selected: 0,
          options: const <ProfileOption<int>>[
            ProfileOption<int>(value: 0, label: 'Débutant'),
            ProfileOption<int>(value: 1, label: 'Confirmé'),
          ],
        );
      });

      await tester.tap(find.text('Confirmé'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ProfileSheetLabels.cancel));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('multiple choice', () {
    testWidgets('toggles both ways and returns the resulting set', (WidgetTester tester) async {
      Set<int>? result;
      await open(tester, (BuildContext c) async {
        result = await showProfileMultiChoiceSheet<int>(
          context: c,
          title: 'Domaines',
          selected: const <int>{0},
          options: const <ProfileOption<int>>[
            ProfileOption<int>(value: 0, label: 'Compute'),
            ProfileOption<int>(value: 1, label: 'Storage'),
            ProfileOption<int>(value: 2, label: 'Networking'),
          ],
        );
      });

      expect(find.byType(ChoiceTile), findsNWidgets(3));
      expectNoStockPicker();

      await tester.tap(find.text('Networking')); // add
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compute')); // remove
      await tester.pumpAndSettle();
      await tester.tap(find.text(ProfileSheetLabels.save));
      await tester.pumpAndSettle();

      expect(result, <int>{2});
    });
  });

  group('text edit', () {
    testWidgets('blocks the commit while the value is invalid', (WidgetTester tester) async {
      String? result = 'untouched';
      await open(tester, (BuildContext c) async {
        result = await showProfileTextSheet(
          context: c,
          title: 'Modifier le pseudo',
          hint: 'Pseudo',
          initial: 'Gabriel C',
          validate: (String v) =>
              RegExp(r'^[a-z0-9_]*$').hasMatch(v) ? null : ProfileSheetLabels.handleRule,
        );
      });

      // The initial value is invalid, so the rule shows and the button is dead.
      expect(find.text(ProfileSheetLabels.handleRule), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text(ProfileSheetLabels.save));
      await tester.pumpAndSettle();
      expect(result, 'untouched', reason: 'an invalid handle must not commit');

      await tester.enterText(find.byType(TextField), 'gabriel_c');
      await tester.pumpAndSettle();
      expect(find.text(ProfileSheetLabels.handleRule), findsNothing);

      await tester.tap(find.text(ProfileSheetLabels.save));
      await tester.pumpAndSettle();
      expect(result, 'gabriel_c');
    });
  });
}
