import 'package:flutter/material.dart';

/// Renders a small, safe subset of inline Markdown as real styled text.
///
/// Authored lesson copy uses lightweight emphasis — `**bold**`, `*italic*`,
/// `***bold italic***` and `` `inline code` `` — to make a key term stand out.
/// Plain [Text] shows those markers literally (the tell-tale "double asterisks
/// everywhere" that reads as raw AI output). [PrismRichText] parses them into
/// genuine [TextSpan] formatting so a lesson looks hand-crafted, like Duolingo.
///
/// Scope is deliberately narrow and inline-only:
///  * `***x***` → bold + italic, `**x**` → bold, `*x*` → italic.
///  * `` `x` `` → monospace inline code (never re-parsed, so `/images/*`
///    keeps its asterisk).
///  * `_`/`__` are intentionally **not** treated as emphasis, so identifiers
///    such as `connection_string` are never mangled.
///
/// Bold/italic spans are parsed recursively, so nested emphasis
/// (`**bold with *italic* inside**`) renders correctly. Unbalanced or stray
/// markers are left untouched as literal characters.
class PrismRichText extends StatelessWidget {
  const PrismRichText(this.text, {super.key, this.style, this.textAlign});

  /// The raw authored string, possibly containing inline Markdown markers.
  final String text;

  /// Base style applied to the whole string; emphasis is layered on top of it.
  /// Falls back to the ambient [DefaultTextStyle] when null.
  final TextStyle? style;

  final TextAlign? textAlign;

  // Order matters: the three-star form must win over the two-star form, which
  // must win over the one-star form, so the longest run of markers binds first.
  // Inline code is matched in the same pass so its contents are shielded from
  // the emphasis rules. `dotAll` lets emphasis span a soft line wrap.
  static final RegExp _pattern = RegExp(
    r'\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+?)`',
    dotAll: true,
  );

  @override
  Widget build(BuildContext context) {
    final TextStyle base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(style: base, children: _inlineSpans(text, base)),
      textAlign: textAlign,
    );
  }

  static List<InlineSpan> _inlineSpans(String input, TextStyle base) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;

    for (final RegExpMatch match in _pattern.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, match.start)));
      }

      final String? boldItalic = match.group(1);
      final String? bold = match.group(2);
      final String? italic = match.group(3);
      final String? code = match.group(4);

      if (boldItalic != null) {
        final TextStyle s = base.merge(
          const TextStyle(
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        );
        spans.add(TextSpan(style: s, children: _inlineSpans(boldItalic, s)));
      } else if (bold != null) {
        final TextStyle s = base.merge(
          const TextStyle(fontWeight: FontWeight.w800),
        );
        spans.add(TextSpan(style: s, children: _inlineSpans(bold, s)));
      } else if (italic != null) {
        final TextStyle s = base.merge(
          const TextStyle(fontStyle: FontStyle.italic),
        );
        spans.add(TextSpan(style: s, children: _inlineSpans(italic, s)));
      } else if (code != null) {
        spans.add(TextSpan(text: code, style: _codeStyle(base)));
      }

      cursor = match.end;
    }

    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }

    return spans;
  }

  static TextStyle _codeStyle(TextStyle base) {
    final Color tint = base.color ?? const Color(0xFF1A1A1A);
    return base.merge(
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const <String>['RobotoMono', 'Menlo', 'Courier'],
        backgroundColor: tint.withOpacity(0.08),
        letterSpacing: 0,
      ),
    );
  }
}
