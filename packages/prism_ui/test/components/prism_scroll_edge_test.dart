import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// A scroll view that ends at a hard border reads as a rendering fault, not as
/// "there is more below" — worst of all when a sticky action bar slices the
/// last row flat.
///
/// What these tests pin is that the signal is **conditional**. A gradient that
/// is always on says "there is more" even when there is not, which is a worse
/// lie than saying nothing. So: present while content remains, absent on a
/// short list, gone once the end is reached — and, critically, the scrollable
/// must not be disturbed by any of it.
void main() {
  Future<void> pump(WidgetTester tester, {required int rows, double height = 300}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: height,
              width: 300,
              child: PrismScrollEdge(
                child: ListView(
                  children: <Widget>[
                    for (int i = 0; i < rows; i++) SizedBox(height: 60, child: Text('row $i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opacity of the trailing scrim. 0 means "no signal shown".
  double trailingOpacity(WidgetTester tester) {
    final Iterable<AnimatedOpacity> all = tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(all, isNotEmpty, reason: 'the scrim should always be mounted');
    return all.last.opacity;
  }

  double scrollOffset(WidgetTester tester) =>
      (tester.state(find.byType(Scrollable)) as ScrollableState).position.pixels;

  testWidgets('content that overflows shows the trailing signal', (WidgetTester tester) async {
    await pump(tester, rows: 20);
    expect(trailingOpacity(tester), 1);
  });

  testWidgets('content that fits shows nothing', (WidgetTester tester) async {
    await pump(tester, rows: 2);
    expect(
      trailingOpacity(tester),
      0,
      reason: 'a fade here would promise content that does not exist',
    );
  });

  testWidgets('reaching the end clears the signal, confirming the end', (
    WidgetTester tester,
  ) async {
    await pump(tester, rows: 20);
    expect(trailingOpacity(tester), 1);

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 4000);
    await tester.pumpAndSettle();

    expect(scrollOffset(tester), 900, reason: 'the fling should reach the end');
    expect(trailingOpacity(tester), 0);
  });

  testWidgets('toggling the signal never disturbs the scroll position', (
    WidgetTester tester,
  ) async {
    // The regression this exists for: an earlier implementation swapped a
    // ShaderMask in and out around the scrollable. Re-parenting rebuilt the
    // ListView and reset its offset to 0 in the middle of a scroll — measured,
    // not theorised.
    await pump(tester, rows: 20);

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 4000);
    await tester.pumpAndSettle();
    expect(scrollOffset(tester), 900);

    await tester.fling(find.byType(ListView), const Offset(0, 4000), 4000);
    await tester.pumpAndSettle();
    expect(scrollOffset(tester), 0);
    expect(trailingOpacity(tester), 1, reason: 'content is below again');
  });

  testWidgets('the scrim never swallows a gesture meant for the list', (
    WidgetTester tester,
  ) async {
    await pump(tester, rows: 20);
    expect(find.text('row 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('row 15'), 200);
    expect(find.text('row 15'), findsOneWidget);
  });

  testWidgets('a viewport shorter than the band still renders', (WidgetTester tester) async {
    await pump(tester, rows: 20, height: 20);
    expect(tester.takeException(), isNull);
  });
}
