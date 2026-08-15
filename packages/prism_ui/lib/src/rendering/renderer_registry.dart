import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'block_fallback.dart';
import 'content_block.dart';

/// Builds a widget for a [ContentBlock]. Registered against a block [type].
typedef BlockRenderer = Widget Function(BuildContext context, ContentBlock block);

/// Maps a content block's wire [ContentBlock.type] to a widget (ADR-003).
///
/// The registry is the single choke point for dynamic content: it resolves a
/// renderer for a block's type, guards the schema version, and — crucially —
/// guarantees [build] never throws. Unknown types, malformed payloads and
/// unsupported schema versions all degrade to a visible [PrismBlockFallback],
/// so a bad block can never take down a lesson.
class RendererRegistry {
  RendererRegistry({int schemaVersion = RendererSchema.current}) : _schemaVersion = schemaVersion;

  final int _schemaVersion;
  final Map<String, BlockRenderer> _renderers = <String, BlockRenderer>{};

  /// The maximum renderer schema version this registry will paint.
  int get schemaVersion => _schemaVersion;

  /// The set of currently registered block types.
  Iterable<String> get registeredTypes => _renderers.keys;

  /// Registers [renderer] for the given block [type], replacing any existing
  /// entry for that type.
  void register(String type, BlockRenderer renderer) {
    _renderers[type] = renderer;
  }

  /// Whether a renderer is registered for [type].
  bool isRegistered(String type) => _renderers.containsKey(type);

  /// Resolves and paints [block], never throwing.
  ///
  /// The resolution order — schema first, then type, then execution — means a
  /// block that targets a future schema is reported as such even if its type is
  /// also unknown, giving the clearest possible fallback message.
  Widget build(BuildContext context, ContentBlock block) {
    if (block.schemaVersion < 1 || block.schemaVersion > _schemaVersion) {
      return PrismBlockFallback(
        reason: BlockFallbackReason.unsupportedSchema,
        blockType: block.type,
        schemaVersion: block.schemaVersion,
      );
    }

    final BlockRenderer? renderer = _renderers[block.type];
    if (renderer == null) {
      return PrismBlockFallback(reason: BlockFallbackReason.unknownType, blockType: block.type);
    }

    try {
      return renderer(context, block);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('RendererRegistry: block "${block.type}" failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return PrismBlockFallback(
        reason: BlockFallbackReason.malformed,
        blockType: block.type,
        detail: kDebugMode ? error.toString() : null,
      );
    }
  }
}
