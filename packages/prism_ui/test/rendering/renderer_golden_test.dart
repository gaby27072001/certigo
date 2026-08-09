// Renderer golden tests for `prism_ui`.
//
// Purpose (DoD): every block type the renderer can emit has a reference visual
// capture, so the dedicated `ci-mobile` golden gate fails on any visual
// regression. The rendered outputs mirror `standardRendererRegistry()` in
// `lib/src/rendering/standard_renderers.dart`:
//
//   hook    -> HookBlock            recap   -> KeyTakeawayBlock
//   concept -> ConceptBlock         callout -> CalloutBlock (info/warning/success)
//   example -> ScenarioBlock        <unmatched / malformed> -> PrismBlockFallback
//   code    -> CodeBlock                                       (3 reasons)
//
// HERMETICITY: this suite imports each concrete component directly and pumps
// blocks in a plain [MaterialApp] whose text theme is Flutter's default test
// font. Keeping global typography out of these captures makes them deterministic
// across platforms. Shadows are disabled and a tolerant comparator (see
// `test/flutter_test_config.dart`) absorbs sub-pixel jitter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_ui/src/components/callout_block.dart';
import 'package:prism_ui/src/components/code_block.dart';
import 'package:prism_ui/src/components/concept_block.dart';
import 'package:prism_ui/src/components/hook_block.dart';
import 'package:prism_ui/src/components/key_takeaway_block.dart';
import 'package:prism_ui/src/components/scenario_block.dart';
import 'package:prism_ui/src/rendering/block_fallback.dart';
import 'package:prism_ui/src/theme/prism_color_scheme.dart';

/// Fixed content width so text wrapping (and therefore block height) is
/// deterministic regardless of the default test surface size.
const double _kBlockWidth = 360;

/// Light theme carrying the [PrismColorScheme] the blocks read via
/// `context.prism`. No typography is configured, so Flutter's default test font
/// is used for every glyph.
ThemeData _theme() => ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  extensions: const <ThemeExtension<dynamic>>[PrismColorScheme.light],
);

void main() {
  setUpAll(() => debugDisableShadows = true);
  tearDownAll(() => debugDisableShadows = false);

  /// Pumps [child] inside a solid-background scaffold at a fixed width and
  /// captures it against `goldens/<name>.png`. Uses a single 16ms frame (never
  /// `pumpAndSettle`) so stateful blocks such as [CodeBlock] settle without
  /// waiting on their tap-triggered timers.
  Future<void> pumpGolden(WidgetTester tester, Widget child, Type finderType, String name) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          body: Center(
            child: SizedBox(
              width: _kBlockWidth,
              child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    await expectLater(find.byType(finderType), matchesGoldenFile('goldens/block_$name.png'));
  }

  testWidgets('hook block golden', (tester) async {
    await pumpGolden(
      tester,
      const HookBlock(text: 'Et si une seule requête pouvait tout changer ?'),
      HookBlock,
      'hook',
    );
  });

  testWidgets('concept block golden', (tester) async {
    await pumpGolden(
      tester,
      const ConceptBlock(
        title: 'Idempotence',
        body:
            'Une opération idempotente produit le même effet '
            'qu\'elle soit appliquée une ou plusieurs fois.',
      ),
      ConceptBlock,
      'concept',
    );
  });

  testWidgets('example (scenario) block golden', (tester) async {
    await pumpGolden(
      tester,
      const ScenarioBlock(
        title: 'Exemple Azure',
        body:
            'Déployez une Function App puis rejouez le pipeline : '
            'le résultat reste stable.',
      ),
      ScenarioBlock,
      'example',
    );
  });

  testWidgets('code block golden', (tester) async {
    await pumpGolden(
      tester,
      const CodeBlock(
        language: 'bash',
        code:
            'az group create \\\n'
            '  --name certigo-rg \\\n'
            '  --location westeurope',
      ),
      CodeBlock,
      'code',
    );
  });

  testWidgets('recap (key takeaway) block golden', (tester) async {
    await pumpGolden(
      tester,
      const KeyTakeawayBlock(
        title: 'À retenir',
        body: 'Un lot = une session = une PR. Idempotent par conception.',
      ),
      KeyTakeawayBlock,
      'recap',
    );
  });

  testWidgets('callout block golden — info', (tester) async {
    await pumpGolden(
      tester,
      const CalloutBlock(
        kind: CalloutKind.info,
        title: 'Info',
        text: 'Les deux dépendances sont mergées sur main.',
      ),
      CalloutBlock,
      'callout_info',
    );
  });

  testWidgets('callout block golden — warning', (tester) async {
    await pumpGolden(
      tester,
      const CalloutBlock(
        kind: CalloutKind.warning,
        title: 'Attention',
        text: 'Ne lancez jamais `flutter test` global : hang garanti.',
      ),
      CalloutBlock,
      'callout_warning',
    );
  });

  testWidgets('callout block golden — success', (tester) async {
    await pumpGolden(
      tester,
      const CalloutBlock(
        kind: CalloutKind.success,
        title: 'OK',
        text: 'La suite golden est verte.',
      ),
      CalloutBlock,
      'callout_success',
    );
  });

  testWidgets('fallback block golden — unknownType', (tester) async {
    await pumpGolden(
      tester,
      const PrismBlockFallback(reason: BlockFallbackReason.unknownType, blockType: 'mystere'),
      PrismBlockFallback,
      'fallback_unknown_type',
    );
  });

  testWidgets('fallback block golden — malformed', (tester) async {
    await pumpGolden(
      tester,
      const PrismBlockFallback(
        reason: BlockFallbackReason.malformed,
        blockType: 'concept',
        detail: 'Champ `body` manquant.',
      ),
      PrismBlockFallback,
      'fallback_malformed',
    );
  });

  testWidgets('fallback block golden — unsupportedSchema', (tester) async {
    await pumpGolden(
      tester,
      const PrismBlockFallback(
        reason: BlockFallbackReason.unsupportedSchema,
        blockType: 'callout',
        schemaVersion: 99,
      ),
      PrismBlockFallback,
      'fallback_unsupported_schema',
    );
  });
}
