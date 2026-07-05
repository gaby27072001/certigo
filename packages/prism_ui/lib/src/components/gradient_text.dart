import 'package:flutter/material.dart';

/// Paints [text] filled with a [gradient] using a [ShaderMask].
///
/// Used for the emphasised second line of a hero title (Luma-style "Start
/// Here"), where the brand gradient (Azure → violet → ember) sweeps across the
/// glyphs. The [style]'s color is irrelevant — the shader replaces it via
/// [BlendMode.srcIn] — but its size/weight still drive layout.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final Gradient gradient;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        // Opaque white so srcIn keeps the full gradient (only alpha is used).
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
