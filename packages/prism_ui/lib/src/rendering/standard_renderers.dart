import 'package:flutter/widgets.dart';

import '../components/callout_block.dart';
import '../components/code_block.dart';
import '../components/concept_block.dart';
import '../components/hook_block.dart';
import '../components/key_takeaway_block.dart';
import '../components/scenario_block.dart';
import 'content_block.dart';
import 'renderer_registry.dart';

/// Builds a [RendererRegistry] pre-wired with Certigo's built-in pedagogical
/// blocks (ADR-003).
///
/// This wiring lives apart from the hermetic [RendererRegistry] core because it
/// reaches into the concrete prism_ui block widgets. Each renderer reads its
/// payload defensively via [ContentBlock]; a missing required field raises a
/// [FormatException] that [RendererRegistry.build] converts into a
/// malformed-data fallback, so a bad payload can never crash a lesson.
RendererRegistry standardRendererRegistry({
  int schemaVersion = RendererSchema.current,
}) {
  final RendererRegistry registry = RendererRegistry(schemaVersion: schemaVersion);

  registry.register(
    'hook',
    (BuildContext context, ContentBlock block) => HookBlock(text: block.requireString('body')),
  );

  registry.register(
    'concept',
    (BuildContext context, ContentBlock block) => ConceptBlock(
      title: block.optionalString('title'),
      body: block.requireString('body'),
    ),
  );

  registry.register(
    'example',
    (BuildContext context, ContentBlock block) {
      final String? title = block.optionalString('title');
      final String body = block.requireString('body');
      return title != null ? ScenarioBlock(title: title, body: body) : ScenarioBlock(body: body);
    },
  );

  registry.register(
    'code',
    (BuildContext context, ContentBlock block) => CodeBlock(
      code: block.requireString('code'),
      language: block.optionalString('language'),
    ),
  );

  registry.register(
    'recap',
    (BuildContext context, ContentBlock block) {
      final String? title = block.optionalString('title');
      final String body = block.requireString('body');
      return title != null
          ? KeyTakeawayBlock(title: title, body: body)
          : KeyTakeawayBlock(body: body);
    },
  );

  registry.register(
    'callout',
    (BuildContext context, ContentBlock block) => CalloutBlock(
      kind: _calloutKind(block.optionalString('kind')),
      title: block.optionalString('title'),
      text: block.requireString('body'),
    ),
  );

  return registry;
}

/// Maps a loose wire string onto a [CalloutKind], defaulting to info.
CalloutKind _calloutKind(String? raw) {
  return switch (raw?.trim().toLowerCase()) {
    'warning' || 'warn' || 'pitfall' || 'danger' => CalloutKind.warning,
    'success' || 'ok' || 'tip' => CalloutKind.success,
    _ => CalloutKind.info,
  };
}
