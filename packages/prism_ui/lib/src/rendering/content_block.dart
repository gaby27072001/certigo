import 'package:flutter/foundation.dart';

/// Renderer schema versioning for the dynamic content pipeline (ADR-003).
///
/// The schema is expressed on the wire as `renderer/N` (e.g. `renderer/1`).
/// A [RendererRegistry] only paints blocks whose version it [supports]; anything
/// newer is surfaced as a fallback instead of crashing the lesson.
abstract final class RendererSchema {
  /// The highest renderer schema version this build understands.
  static const int current = 1;

  /// The wire prefix used in `renderer/N` tags.
  static const String prefix = 'renderer';

  /// Formats [version] as its wire tag, e.g. `tag(1) == 'renderer/1'`.
  static String tag(int version) => '$prefix/$version';

  /// Whether [version] can be rendered by this build (`1..current`).
  static bool supports(int version) => version >= 1 && version <= current;

  /// Parses a schema descriptor into an integer version.
  ///
  /// Accepts an [int], any [num], or a [String] shaped either as a bare integer
  /// (`'2'`) or as a wire tag (`'renderer/2'`). Anything unrecognised — a
  /// missing or garbled value — defaults to [current] so rendering never throws
  /// during parsing; an unsupported *explicit* version is still surfaced as a
  /// fallback by the registry.
  static int parse(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      final String value = raw.trim();
      final int? direct = int.tryParse(value);
      if (direct != null) {
        return direct;
      }
      if (value.startsWith('$prefix/')) {
        final int? tagged =
            int.tryParse(value.substring(prefix.length + 1).trim());
        if (tagged != null) {
          return tagged;
        }
      }
    }
    return current;
  }
}

/// A backend-agnostic unit of lesson content addressed by its wire [type].
///
/// The dynamic renderer maps [type] → a widget through a [RendererRegistry].
/// [data] carries the block payload (read defensively by renderers) and
/// [schemaVersion] gates compatibility. Keeping content decoupled from concrete
/// widgets is what lets the backend introduce new block types without shipping a
/// new app — unknown types simply degrade to a visible fallback.
@immutable
class ContentBlock {
  const ContentBlock({
    required this.type,
    this.data = const <String, dynamic>{},
    this.schemaVersion = RendererSchema.current,
  });

  /// Builds a block from a decoded JSON map, tolerating absent or loosely typed
  /// fields so a malformed payload becomes a fallback rather than a crash.
  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final Object? rawData = json['data'];
    final Map<String, dynamic> data = switch (rawData) {
      final Map<String, dynamic> typed => typed,
      final Map<Object?, Object?> loose => loose.map(
          (Object? key, Object? value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        ),
      _ => const <String, dynamic>{},
    };
    return ContentBlock(
      type: (json['type'] ?? '').toString(),
      data: data,
      schemaVersion: RendererSchema.parse(
        json['schemaVersion'] ?? json['schema'] ?? json['version'],
      ),
    );
  }

  /// The registered type key (e.g. `hook`, `concept`, `code`).
  final String type;

  /// The block payload. Renderers read from this map defensively.
  final Map<String, dynamic> data;

  /// The renderer schema version this block targets.
  final int schemaVersion;

  /// Reads [key] as a non-empty [String].
  ///
  /// Throws a [FormatException] when the field is absent, empty or not a string
  /// — the registry catches this and renders a malformed-data fallback.
  String requireString(String key) {
    final Object? value = data[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException(
      'ContentBlock("$type") requires a non-empty string field "$key"',
      data,
    );
  }

  /// Reads [key] as a non-empty [String] when present, otherwise `null`.
  String? optionalString(String key) {
    final Object? value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }
}
