import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget tests for the winding skill-path building blocks: [PathNode],
/// [MascotAvatar] and [UnitHeader].
///
/// Like the coach-card tests these are router-free and presentational — pumped
/// under a bare [PrismTheme] host with no backend, network or GoRouter — so we
/// can assert the French labels, status visuals and tap affordances directly.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: PrismTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  group('PathNode', () {
    testWidgets('available lesson shows its star + caption and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          PathNode(
            status: PathNodeStatus.available,
            label: 'Stockage Azure',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Stockage Azure'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_rounded));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('locked node is inert and reads "verrouillée"', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      var tapped = false;
      await tester.pumpWidget(
        host(
          PathNode(status: PathNodeStatus.locked, label: 'Gouvernance', onTap: () => tapped = true),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      // The node merges its visible title with a French status word for a11y.
      final node = tester.getSemantics(find.byType(PathNode));
      expect(node.label, contains('Gouvernance'));
      expect(node.label, contains('verrouillée'));

      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pump();
      expect(tapped, isFalse);
      handle.dispose();
    });

    testWidgets('mastered node wears the gold crown', (tester) async {
      await tester.pumpWidget(
        host(const PathNode(status: PathNodeStatus.mastered, label: 'Identité')),
      );
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    });

    testWidgets('current node floats its start call-out', (tester) async {
      await tester.pumpWidget(
        host(
          const PathNode(
            status: PathNodeStatus.inProgress,
            label: 'Réseau',
            current: true,
            startLabel: 'REPRENDRE',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('REPRENDRE'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('cleared checkpoint shows the trophy', (tester) async {
      await tester.pumpWidget(
        host(
          const PathNode(
            status: PathNodeStatus.completed,
            kind: PathNodeKind.checkpoint,
            label: 'Révision',
          ),
        ),
      );
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });
  });

  group('MascotAvatar', () {
    testWidgets('exposes the French name + role for accessibility', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const MascotAvatar(mascot: AuroraMascot.nimbus)));

      expect(find.bySemanticsLabel('Nimbus, la mascotte Azure'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_rounded), findsOneWidget);
      handle.dispose();
    });

    testWidgets('is a button and fires onTap when interactive', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(MascotAvatar(mascot: AuroraMascot.sentinel, onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(MascotAvatar));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('UnitHeader', () {
    testWidgets('renders the unit index, title, domain and lesson count', (tester) async {
      await tester.pumpWidget(
        host(
          const UnitHeader(
            index: 1,
            title: 'Fondamentaux du cloud',
            accent: Color(0xFF3BA0F0),
            domainName: 'Concepts cloud',
            mascot: AuroraMascot.nimbus,
            completed: 2,
            total: 4,
          ),
        ),
      );

      expect(find.text('UNITÉ 1'), findsOneWidget);
      expect(find.text('Fondamentaux du cloud'), findsOneWidget);
      expect(find.text('Concepts cloud'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
    });
  });
}
