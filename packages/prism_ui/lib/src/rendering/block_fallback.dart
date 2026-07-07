import 'package:flutter/material.dart';

/// Why a [PrismBlockFallback] is being shown in place of real content.
enum BlockFallbackReason {
  /// The block `type` is not registered in the [RendererRegistry].
  unknownType,

  /// The block payload was present but could not be read (missing/invalid data).
  malformed,

  /// The block targets a renderer schema version this build cannot paint.
  unsupportedSchema,
}

/// A resilient placeholder rendered whenever a content block cannot be painted.
///
/// This widget is deliberately built from raw Material primitives and the
/// ambient [Theme] only — it never reads the Prism design-system extension — so
/// it can be shown even when the surrounding theme is incomplete. It is the last
/// line of defence for ADR-003: a lesson degrades to a visible, labelled card
/// instead of throwing.
class PrismBlockFallback extends StatelessWidget {
  const PrismBlockFallback({
    required this.reason,
    this.blockType,
    this.schemaVersion,
    this.detail,
    super.key,
  });

  /// A stable key so tests (and callers) can locate any fallback on screen.
  static const Key rootKey = Key('prism.block.fallback');

  /// The reason this fallback replaced real content.
  final BlockFallbackReason reason;

  /// The offending block type, when known.
  final String? blockType;

  /// The block's declared schema version, when relevant.
  final int? schemaVersion;

  /// Optional diagnostic detail (surfaced in debug builds only by callers).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'Bloc de contenu de repli',
      child: Card(
        key: rootKey,
        color: colors.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.error.withOpacity(0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_icon(), color: colors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _title(),
                      style: text.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _message(),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (detail != null && detail!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        detail!,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon() {
    return switch (reason) {
      BlockFallbackReason.unknownType => Icons.help_outline,
      BlockFallbackReason.malformed => Icons.report_gmailerrorred_outlined,
      BlockFallbackReason.unsupportedSchema => Icons.system_update_alt_outlined,
    };
  }

  String _title() {
    return switch (reason) {
      BlockFallbackReason.unknownType => 'Contenu indisponible',
      BlockFallbackReason.malformed => 'Contenu illisible',
      BlockFallbackReason.unsupportedSchema => 'Mise à jour requise',
    };
  }

  String _message() {
    return switch (reason) {
      BlockFallbackReason.unknownType => blockType != null && blockType!.isNotEmpty
          ? 'Ce type de bloc ("$blockType") n\'est pas pris en charge par cette version.'
          : 'Ce type de bloc n\'est pas pris en charge par cette version.',
      BlockFallbackReason.malformed =>
        'Les données de ce bloc sont incomplètes ou invalides.',
      BlockFallbackReason.unsupportedSchema => schemaVersion != null
          ? 'Ce contenu (renderer/$schemaVersion) nécessite une version plus récente de l\'application.'
          : 'Ce contenu nécessite une version plus récente de l\'application.',
    };
  }
}
