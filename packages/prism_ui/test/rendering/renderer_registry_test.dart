// Hermetic tests for the dynamic renderer core (ADR-003).
//
// These tests import the rendering primitives directly and pump them inside a
// plain [MaterialApp] to keep registry behavior independent from the complete
// theme. The concrete `standard` wiring is covered by `flutter analyze` and the
// app integration instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/src/rendering/block_fallback.dart';
import 'package:prism_ui/src/rendering/content_block.dart';
import 'package:prism_ui/src/rendering/renderer_registry.dart';

/// A trivial, font-free stand-in for a "real" registered block widget.
class _ProbeBlock extends StatelessWidget {
  const _ProbeBlock(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

/// Builds a registry whose only renderer reads a required `body` field, so we
/// can exercise the known / malformed paths without any real block widget.
RendererRegistry _probeRegistry({int schemaVersion = RendererSchema.current}) {
  return RendererRegistry(schemaVersion: schemaVersion)
    ..register(
      'hook',
      (BuildContext context, ContentBlock block) => _ProbeBlock(block.requireString('body')),
    );
}

Future<void> _pumpBlock(WidgetTester tester, RendererRegistry registry, ContentBlock block) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(builder: (BuildContext context) => registry.build(context, block)),
      ),
    ),
  );
}

void main() {
  group('RendererSchema.parse', () {
    test('reads a bare integer', () {
      expect(RendererSchema.parse(2), 2);
    });

    test('reads a numeric string', () {
      expect(RendererSchema.parse('3'), 3);
    });

    test('reads a renderer/N wire tag', () {
      expect(RendererSchema.parse('renderer/4'), 4);
    });

    test('defaults to current for missing or garbled values', () {
      expect(RendererSchema.parse(null), RendererSchema.current);
      expect(RendererSchema.parse('not-a-version'), RendererSchema.current);
      expect(RendererSchema.parse(<String, dynamic>{}), RendererSchema.current);
    });

    test('supports only 1..current', () {
      expect(RendererSchema.supports(1), isTrue);
      expect(RendererSchema.supports(RendererSchema.current), isTrue);
      expect(RendererSchema.supports(0), isFalse);
      expect(RendererSchema.supports(RendererSchema.current + 1), isFalse);
    });
  });

  group('RendererRegistry API', () {
    test('register / isRegistered / registeredTypes', () {
      final RendererRegistry registry = _probeRegistry();
      expect(registry.isRegistered('hook'), isTrue);
      expect(registry.isRegistered('totally-unknown'), isFalse);
      expect(registry.registeredTypes, contains('hook'));
    });

    test('exposes its schema ceiling', () {
      expect(_probeRegistry().schemaVersion, RendererSchema.current);
      expect(_probeRegistry(schemaVersion: 3).schemaVersion, 3);
    });
  });

  group('RendererRegistry.build', () {
    testWidgets('paints the registered widget for a known, well-formed block', (
      WidgetTester tester,
    ) async {
      await _pumpBlock(
        tester,
        _probeRegistry(),
        const ContentBlock(type: 'hook', data: <String, dynamic>{'body': 'Bienvenue sur Azure'}),
      );

      expect(find.byType(_ProbeBlock), findsOneWidget);
      expect(find.text('Bienvenue sur Azure'), findsOneWidget);
      expect(find.byKey(PrismBlockFallback.rootKey), findsNothing);
    });

    testWidgets('falls back for an unknown block type', (WidgetTester tester) async {
      await _pumpBlock(
        tester,
        _probeRegistry(),
        const ContentBlock(type: 'totally-unknown', data: <String, dynamic>{'body': 'x'}),
      );

      expect(find.byKey(PrismBlockFallback.rootKey), findsOneWidget);
      expect(find.byType(_ProbeBlock), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back for a malformed payload (missing required field)', (
      WidgetTester tester,
    ) async {
      await _pumpBlock(
        tester,
        _probeRegistry(),
        // `hook` requires a non-empty `body`; here it is absent, so the
        // renderer throws a FormatException that build() must swallow.
        const ContentBlock(type: 'hook', data: <String, dynamic>{}),
      );

      expect(find.byKey(PrismBlockFallback.rootKey), findsOneWidget);
      expect(find.byType(_ProbeBlock), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back for an unsupported (future) schema version', (
      WidgetTester tester,
    ) async {
      await _pumpBlock(
        tester,
        _probeRegistry(),
        const ContentBlock(
          type: 'hook',
          data: <String, dynamic>{'body': 'x'},
          schemaVersion: RendererSchema.current + 1,
        ),
      );

      expect(find.byKey(PrismBlockFallback.rootKey), findsOneWidget);
      expect(find.byType(_ProbeBlock), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back for an invalid (below-range) schema version', (
      WidgetTester tester,
    ) async {
      await _pumpBlock(
        tester,
        _probeRegistry(),
        const ContentBlock(type: 'hook', data: <String, dynamic>{'body': 'x'}, schemaVersion: 0),
      );

      expect(find.byKey(PrismBlockFallback.rootKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('never throws even when a renderer itself misbehaves', (WidgetTester tester) async {
      final RendererRegistry registry = RendererRegistry()
        ..register(
          'boom',
          (BuildContext context, ContentBlock block) => throw StateError('renderer exploded'),
        );

      await _pumpBlock(tester, registry, const ContentBlock(type: 'boom'));

      expect(find.byKey(PrismBlockFallback.rootKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
