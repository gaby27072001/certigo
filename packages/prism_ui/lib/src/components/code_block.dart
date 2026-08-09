import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// A syntax-tinted code block with a tap-to-copy affordance.
///
/// Rendered on a deep-navy slab (independent of light/dark) so monospaced
/// snippets keep contrast and feel like a terminal embedded in the lesson —
/// essential for cloud/CLI teaching (az, PowerShell, Bicep, KQL…).
class CodeBlock extends StatefulWidget {
  const CodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.brightness == Brightness.dark ? const Color(0xFF0A0F1C) : const Color(0xFF111A2E),
        borderRadius: PrismRadii.cardMd,
        border: Border.all(color: p.border.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (widget.language != null)
                Text(
                  widget.language!.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: Colors.white54, letterSpacing: 1),
                ),
              const Spacer(),
              _CopyButton(copied: _copied, onTap: _copy),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            widget.code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: <String>['JetBrains Mono', 'Menlo', 'Consolas'],
              color: Color(0xFFD6E2FF),
              height: 1.5,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    const Color ok = Color(0xFF6BE0A6);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            copied ? Icons.check_rounded : Icons.copy_rounded,
            size: 15,
            color: copied ? ok : Colors.white60,
          ),
          const SizedBox(width: 5),
          Text(
            copied ? 'Copié' : 'Copier',
            style: t.labelSmall?.copyWith(color: copied ? ok : Colors.white60),
          ),
        ],
      ),
    );
  }
}
